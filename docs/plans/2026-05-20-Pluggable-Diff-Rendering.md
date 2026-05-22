# Pluggable diff rendering

Let custom matchers ship their own diff partial when the default tree-walker table doesn't capture the shape of what they actually scored.

## Why

The per-example show page (`/eval_engine/:name/examples/:key`) renders a score-tree diff by walking `score_tree`, `expected`, and `output` in parallel, producing a flat table of `path / expected / output / score` rows. This works for every built-in type because `output_type.validate` enforces parity between expected and output shapes — the walker can dereference both by the same key/index at every level.

Custom matchers don't have to respect that invariant. A matcher might score by extracting features from `output` against richer `expected` data (regex patterns, weighted rubrics, multi-stage scoring). For these, the parallel walker either chokes or produces nonsense rows, and even when it doesn't, the resulting table buries what the matcher actually evaluated. Each custom matcher is the only thing that knows how to surface its own reasoning to the user — let it provide a partial.

## Shape of the change

- Each `Types::Base` subclass declares its diff partial via a `diff_partial_path` instance method; the default returns the existing tree-walker partial.
- `Types::CustomType` delegates `diff_partial_path` to its wrapped matcher when the matcher implements it; otherwise it falls through to the default walker. The mismatched-shape case is the exception, not the norm — the matcher author opts out of the walker only when they need to.
- `ExamplesController#show` loads the eval class once and assigns `@output_type = Loader.load_eval(@eval_name).output_type` (the existing "eval not found" check already guards this; other load errors propagate as 500 the same as they would today).
- The show template calls `render_diff_for(output_type:, eval_name:, score_tree:, expected:, output:)` — a new `EvalsHelper` method that does the dispatch. Keywords are explicit (not `**locals`) so the partial contract is greppable from the call site.
- All partials receive the same locals contract: `score_tree`, `expected`, `output`. View context is available naturally (it's a partial).

### Failure modes — raise loudly with actionable messages

Programmer errors (misconfigured matcher, typo in partial path) should fail fast with a clear diagnosis, not paper over with a fallback panel. `EvalEngine::DiffRendering::ConfigurationError` is raised by `render_diff_for` in three cases:

```
Cannot render diff: output_type is nil for eval 'is_ebike_manufacturer'.
This usually means the eval class did not call `output_type` at the class
level. Add an `output_type :string` (or similar) declaration.
```

```
Cannot render diff: WeightedRubricMatcher#diff_partial_path returned
nil (expected a String). Either remove the method to use the default
walker, or return a partial path like "evals/diffs/weighted_rubric".
```

```
Cannot render diff: partial "evals/diffs/weighted_rubric" not found
(returned by WeightedRubricMatcher#diff_partial_path). Looked under
the standard view paths; expected a file at
app/views/evals/diffs/_weighted_rubric.html.erb. Fix the matcher's
return value or create the partial.
```

Each error message names the offending thing AND the fix. The third case rescues `ActionView::MissingTemplate` inside `render_diff_for` and re-raises with the more useful message (the standard error already contains the search paths, which we include).

### Partial path resolution

The string returned by `diff_partial_path` is a **plain Rails partial reference** — no special engine-vs-app namespacing. Rails resolves it against the combined view paths of (host app + every loaded engine), with host paths taking precedence. Practical consequences:

- **Engine ships its default walker at `app/views/eval_engine/diffs/_walker.html.erb`.** It's referenced as `"eval_engine/diffs/walker"` and resolves to that file by default.
- **Hosts can override the default walker** by dropping their own `app/views/eval_engine/diffs/_walker.html.erb` in the host app. Host wins.
- **Custom matchers reference any path in any view tree.** A matcher in the host app typically returns something like `"evals/diffs/weighted_rubric"` → `app/views/evals/diffs/_weighted_rubric.html.erb` in the host. A matcher shipped in a gem can return `"my_gem/diffs/foo"` → `app/views/my_gem/diffs/_foo.html.erb` in the gem's engine.
- **The caller controls the path entirely** — `diff_partial_path` returns whatever string the matcher wants, and Rails resolves it through the same mechanism as any other `render "path"` call.

## API surface

### Types layer

```ruby
class Types::Base
  def diff_partial_path
    "eval_engine/diffs/walker"
  end
end

class Types::CustomType < Base
  def diff_partial_path
    return @matcher.diff_partial_path if @matcher.respond_to?(:diff_partial_path)

    super
  end
end
```

That's the whole hook. Built-in types (string, integer, float, boolean, hash, array) inherit the default. A custom matcher that wants to override just defines a single method returning its partial path:

```ruby
class WeightedRubricMatcher
  def match(actual, expected) = ...
  def diff_partial_path = "evals/diffs/weighted_rubric"
end
```

### Partial contract

Every diff partial is rendered with locals:

- `score_tree` — the snapshotted score tree from this RunExample (`{score:, children:}` recursively).
- `expected` — the expected value as stored on this RunExample (whatever shape the matcher wants — may include metadata).
- `output` — the value `generate` returned for this run.

Partials live wherever they're discoverable by Rails' view path. The default walker ships at `app/views/eval_engine/diffs/_walker.html.erb` in the engine. Host-app or custom-matcher partials live in the host's view paths (`app/views/evals/diffs/_weighted_rubric.html.erb` or wherever) — referenced by the path returned from `diff_partial_path`.

**Helper availability in host-app partials.** Pure presentation primitives (`format_score`, `score_class`, `diff_row_color`, `format_diff_value`) live in `EvalEngine::DiffPresentationHelper` and are pushed onto `ActionController::Base` via an engine initializer, so every host-app view (and any custom diff partial under `app/views/evals/diffs/`) can call them without manual setup. This keeps visual consistency between custom partials and the default walker without forcing each author to re-derive the HSL gradient formula.

Walker-internal helpers (`diff_rows`, `walk_diff`, `walk_hash_children`, etc.) stay in `EvalsHelper` — they're tied to the score-tree walking algorithm, not to general presentation. Custom partials that genuinely want to walk a score tree can `include EvalEngine::EvalsHelper` themselves, but that's rare.

### What the default walker contains

Exactly today's tree-walk table, lifted from `examples/show.html.erb` (lines ~26-53). The helpers it uses (`diff_rows`, `format_diff_value`, `diff_row_color`, `walk_diff` and friends in `EvalsHelper`) stay where they are — the partial just calls them.

## Score-tree identity

We do not store which matcher produced a given score_tree. The view always renders with the *current* `output_type` for that eval (from `Loader.load_eval(eval_name).output_type`). Rationale:

- The matcher author handles defensive cases inside their own partial (shape mismatches, missing keys, etc.). Existing data structures don't carry version info today, and adding matcher identity to RunExample for this rare case is overkill.
- If a user changes the matcher's expected shape and views an old run, that's an interpretation question only the matcher's partial author can answer — the engine can't second-guess it.

**Consequence to flag for future maintainers**: after a matcher changes shape, old runs may render garbage (or differently than when they were recorded). We don't surface this in the UI — it's noise for the common case — but the next person extending diff rendering should know that "render with current matcher" is a deliberate choice with this tradeoff, not an oversight.

## Test strategy

- `Types::Base#diff_partial_path` returns the default path: tiny unit test per built-in type (parametrize).
- `Types::CustomType#diff_partial_path` delegates to the matcher when the matcher implements it; otherwise falls back: two unit tests.
- The default walker partial: extract a view spec equivalent to the current diff assertions in `examples_spec.rb` (the `hsl(0.0, ...)` / `hsl(120.0, ...)` row-color checks). Existing request specs through `examples/show.html.erb` keep passing as integration coverage.
- The per-example show request spec gains one happy-path case: an eval whose `output_type` is a `CustomType` wrapping a matcher with `diff_partial_path` returning a fixture partial — assert the fixture's content appears in the response.
- A new helper spec for `render_diff_for` exercises the three error-raising paths:
  1. Output type nil → raises `EvalEngine::DiffRendering::ConfigurationError` with "output_type is nil" + eval name in the message.
  2. `diff_partial_path` returns a non-String — raises with the matcher class name and the offending return value's class in the message.
  3. `diff_partial_path` returns a path Rails can't resolve — raises with the missing path and the matcher class name in the message.

## Out of scope (followups)

- Style/CSS scaffolding for custom partials. The engine ships its own classes; custom partials are on their own.
- **CLI rendering symmetry.** The CLI's `debug` command keeps its raw `score_tree` dump. The `score_tree` is the matcher's canonical record of what happened — custom matchers can embed any reasoning they want as extra keys (the engine treats it as opaque JSON), and the CLI dump will surface those keys without further work. If a future user wants pretty terminal output, mirror `diff_partial_path` with a `render_diff_text(score_tree, expected, output) → String` hook on the matcher; same dispatch shape, no plan changes here required to leave that door open.
- Per-row deep-dive interaction (collapsing nested score branches, drilldown to sub-scores). Custom partials can implement this themselves; the engine doesn't ship it.
- Storing matcher identity / version on `RunExample` for historical-render fidelity (see "Score-tree identity" above).

## Tasks

1. Add `Types::Base#diff_partial_path` and a `CustomType` override that delegates to the matcher. Add unit tests for both.
2. Wire `@output_type = Loader.load_eval(@eval_name).output_type` into `ExamplesController#show`, after the existing not-found check.
3. Extract the existing diff-table block from `examples/show.html.erb` into `app/views/eval_engine/diffs/_walker.html.erb`. Add `EvalEngine::DiffRendering::ConfigurationError` and a `render_diff_for(output_type:, eval_name:, score_tree:, expected:, output:)` helper in `EvalsHelper` that raises that error with actionable messages for the three failure modes. Update the show template to call the helper. Extract `format_score`, `score_class`, `diff_row_color`, `format_diff_value` from `EvalsHelper` into a new `EvalEngine::DiffPresentationHelper`; have `EvalsHelper include` it; add an engine initializer that does `ActiveSupport.on_load(:action_controller_base) { helper EvalEngine::DiffPresentationHelper }` so host views can use the primitives. Keep walker-internal helpers (`diff_rows`, `walk_diff`, etc.) in `EvalsHelper`.
4. Add request-spec coverage for the happy path and helper-spec coverage for the three error cases.
5. Update the parent eval-engine plan's "Escape hatch: custom matchers" section (lines 397-411 of `2026-05-13-Eval-Engine.md`) to mention the new optional `diff_partial_path` method and the path-resolution rules.
