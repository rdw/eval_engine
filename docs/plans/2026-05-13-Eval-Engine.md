# Eval Engine

Make developing prompts more reliable by authoring evals easily.
  - Improve human productivity by providing a HTML UI that runs the evals and displays their results.
  - Improve agent productivity with a simple but powerful CLI and Ruby API.


## Directory Layout

Evals live under a configurable root directory (default: `eval/` in the Rails app root, configurable via `EvalEngine.configure { |c| c.eval_root = "..." }` in an initializer).  The engine can use its own database connection (separate from the host app's primary database) or share the host's database — see "Database connection" under "Runs" below.

Each eval is a subdirectory containing its module, examples, and supporting files:

```
eval/
  is_ebike_manufacturer/
    is_ebike_manufacturer_eval.rb     # Eval module (the code)
    examples/
      blixbike.yaml                   # One file per example (input + expected)
      heybike.yaml
      amazon.yaml
    files/                            # Checked-in supporting files (HTML caches, fixtures, etc.)
      tmp/                            # Large files not checked in (.gitignored)
```

**Naming conventions:**
- The subdirectory name IS the eval name (e.g., `is_ebike_manufacturer`).
- The Ruby file is `<name>_eval.rb`.  The `_eval` suffix is intentional — it makes the file instantly distinguishable in editor tabs and search results.
- Example filenames are the example key.  Must be unique within the eval and use filename-safe characters.  No separate `get_key` method is needed.


## Eval Module

Each eval is a Ruby class that inherits from `EvalEngine::Eval`.  It lives at `eval/<name>/<name>_eval.rb`.

### Minimal example

```ruby
class IsEbikeManufacturerEval < EvalEngine::Eval
  output_type :string, match: :exact

  def generate(input)
    url = input["url"]
    html = read_file("cache/#{sanitize_filename(url)}.html")
    Prompts::ProductNameAgent.new.is_ebike_manufacturer?(html)
  end
end
```

### Contract

- **`generate(input)`** (required): Accepts a primitive-data input, runs the code under test (typically an LLM prompt, but not required), returns an output matching the declared `output_type`.  The return value can be primitive data (a hash, array, string, etc.) or an `EvalEngine::DataType` instance — `DataType` instances are automatically converted to primitive data before storage.
- **`output_type`** (required): Class-level declaration of the output's shape and how to score it.  See "Types and Matching" below.
- **`input_type`** (optional, future): Class-level declaration of the input's shape, for validation.

### Primitive data

Both inputs and outputs must be **primitive data**: Ruby hashes, arrays, strings, numbers, booleans, and nil.  No symbols, dates, or custom objects.  This ensures safe round-tripping through both YAML (on disk) and JSON (in the database).

Example YAML files are loaded with `YAML.safe_load` (with `permitted_classes: []`) to enforce this — bare dates, symbols, and other YAML-specific types are rejected at load time.

The purpose of `generate` is to bridge between primitive data and the application's internal types — read from files, instantiate domain objects, call the code under test, then convert the result back to primitive data before returning.

### File access

The base class provides helper methods for accessing the eval's `files/` directory:

- **`files_path(relative_path)`** — Returns the absolute path to a file under `eval/<name>/files/`.  Useful for passing paths to external code.
- **`read_file(relative_path)`** — Reads and returns the contents of a file under `files/`.

The `files/` directory is for checked-in supporting files (cached HTML pages, fixture data, etc.).  The `files/tmp/` subdirectory is `.gitignored` and available for large generated files that shouldn't be in source control.  Both are accessible through the same helpers.

These are instance methods on `self`, so no explicit context parameter is needed.  The application can extend `EvalEngine::Eval` with additional helpers (e.g., a `with_http_cache` method that wraps HTTP caching) by including a module:

```ruby
# In the host app's initializer:
EvalEngine::Eval.include(MyCachingHelpers)
```

This way, every eval has access to application-specific conveniences without the engine needing to know about them.


## Examples

Each example is a single YAML file under `eval/<name>/examples/`.  The filename (minus `.yaml`) is the example's key.

### Shape

```yaml
# eval/is_ebike_manufacturer/examples/blixbike.yaml
input:
  url: "https://blixbike.com/"
expected: "manufacturer"
```

- **`input`**: The value passed to `generate`.  Can be any primitive data (a string, a hash, an array, etc.).
- **`expected`**: Must match the shape declared by `output_type`.  For the simple `output_type :string` above, this is a bare string.  For a hash output type, it would be a nested hash with the same fields.
- The key is the filename (`blixbike`), not a field inside the file.

### CRUD

Examples are created and edited as plain YAML files — by hand, by code, or through the UI (which writes to disk).  They are checked in to source control.

### Programmatic creation

The engine provides a Ruby API for creating examples, since it's common to bake real-life situations into evals programmatically:

- **`EvalEngine.create_example(eval_name, key, input:, expected:)`** — Creates the YAML file at the correct path.  Validates `input` and `expected` against the eval's declared types.  The `key` is sanitized to be filename-safe (see below).
- **`EvalEngine.sanitize_key(string)`** — Converts an arbitrary string (e.g., a URL or title) into a filename-safe key: lowercased, non-alphanumeric characters replaced with underscores, truncated to a reasonable length, uniqueness-suffixed if needed.
- **`EvalEngine.save_file(eval_name, relative_path, content)`** — Writes a file into the eval's `files/` directory.  Useful for saving cached HTML, fixture data, or other supporting files alongside the example.

### Shape changes

When the eval's input or output shape changes (e.g., the prompt gains a new argument), stale examples are detected by shape validation at load time.  There are no migrations — the workflow is:

1. Update the eval module's type declarations.
2. Run the eval.  Stale examples fail validation with a clear error.
3. Update the example files (manually, or by accepting new outputs from the UI).


## Runs

Runs are stored in the database (not on disk), providing history, parallel safety, and the ability to recompute scores.

### Database connection

Following the pattern from [Solid Errors](https://github.com/fractaledmind/solid_errors), the engine exposes a `connects_to` setting that the host application can configure to point its tables at any database — its own dedicated DB or the host's primary.

In the host application's `config/environments/production.rb` (typically wired up by an `eval_engine:install` generator):

```ruby
config.eval_engine.connects_to = { database: { writing: :evals } }
```

The engine implements this with:

- `EvalEngine.connects_to` — a `mattr_accessor` on the `EvalEngine` module.
- `EvalEngine::Engine` — declares `config.eval_engine = ActiveSupport::OrderedOptions.new` and an initializer that copies each `config.eval_engine.*` setting onto the `EvalEngine` module.
- `EvalEngine::Record` — an abstract `ActiveRecord::Base` subclass that calls `connects_to(**EvalEngine.connects_to) if EvalEngine.connects_to`.  All engine models (`EvalRun`, `EvalRunExample`, `EvalCheckpoint`) inherit from `EvalEngine::Record` so they share whatever connection the host configured.

When `connects_to` isn't set, models fall through to the host's default connection — so simple apps need no extra configuration.

### Database schema

**`eval_runs`** table:

| Column        | Type      | Notes                                                        |
|--------------|-----------|--------------------------------------------------------------|
| id           | bigint    | PK                                                           |
| eval_name    | string    | Which eval this run belongs to                               |
| status       | string    | `running`, `completed`, `failed` (enum)                      |
| started_at   | datetime  |                                                              |
| finished_at  | datetime  | Null while status is `running`                               |
| example_count| integer   | Number of examples in this run (set at run start)            |
| created_at   | datetime  |                                                              |
| updated_at   | datetime  |                                                              |

The `status` column tracks the run lifecycle: `running` while examples are executing, `completed` when all examples finish (even if some errored), `failed` if the process crashes or is interrupted.  Runs stuck in `running` with a `started_at` older than a configurable timeout are treated as `failed`.

There is no `score` column on `eval_runs`.  Scores are computed dynamically (see "Scoring" below).

**`eval_run_examples`** table:

| Column       | Type     | Notes                                          |
|-------------|----------|-------------------------------------------------|
| id          | bigint   | PK                                              |
| eval_run_id | bigint   | FK to eval_runs                                 |
| example_key | string   | References the example filename                 |
| status      | string   | `passed`, `failed`, `error`                     |
| started_at  | datetime |                                                 |
| finished_at | datetime |                                                 |
| input       | json     | Snapshot of the example's input at run time     |
| expected    | json     | Snapshot of the example's expected at run time  |
| output      | json     | The value returned by `generate` (null on error)|
| score_tree  | json     | Scores-only tree (see "Score Trees" below)      |
| score       | float    | Top-level score for this example (0.0 on error) |
| error       | text     | Exception message + backtrace (null if no error)|

**`eval_checkpoints`** table:

| Column          | Type      | Notes                                 |
|----------------|-----------|---------------------------------------|
| id             | bigint    | PK                                    |
| eval_name      | string    | Unique — one checkpoint per eval      |
| checkpointed_at| datetime  | The point-in-time this checkpoint represents |
| created_at     | datetime  |                                       |
| updated_at     | datetime  |                                       |

### Scoring

Scores are not stored on runs.  Instead, there are two computed scores for each eval:

**Latest score**: For each example currently on disk, find the most recent `eval_run_example` row **across all runs** (by `finished_at`).  The latest score is the **arithmetic mean** of those per-example scores.  This means a single-example re-run updates that example's contribution to the overall score without affecting other examples.  Examples that have never been run are excluded from the mean (and flagged as "not yet run" in the UI).

**Checkpoint score**: Same logic, but only considering `eval_run_example` rows with `finished_at` before the checkpoint's `checkpointed_at` datetime.  If an example has no run result before the checkpoint, it's excluded (and flagged).

This design means:
- **Single-example re-runs compose naturally**: Re-running one example updates its latest score, which flows into the eval's overall latest score.  No special cases needed.
- **N-example runs work the same way**: Running any subset of examples updates exactly those examples' latest scores.
- **Deleting an example YAML file** removes it from the latest score — only examples currently on disk contribute.
- **Deleting old runs** can cause a checkpoint to have incomplete data.  The UI warns if a checkpoint score is based on fewer examples than are currently on disk, and shows how many are covered.  This is not an error — the user may proceed anyway.

### Error handling

When `generate` raises an exception for an example:

1. The example row is saved with `status: "error"`, `score: 0.0`, `output: null`, `score_tree: null`, and the exception message + backtrace in `error`.
2. The run continues with remaining examples — one failure does not abort the run.
3. Errored examples contribute 0.0 to computed scores.

### Checkpointing

A checkpoint is a **point in time**, not a pointer to a specific run.  Promoting sets `checkpointed_at` to the current datetime (or to the `finished_at` of a specific run, if promoting from the runs list).  There is at most **one checkpoint per eval** — promoting replaces the previous checkpoint.

The checkpoint score is the mean of each example's most recent score as of that datetime.  This decouples checkpoints from individual runs and composes naturally with partial re-runs.

### Recomputing scores

Because `output` and `expected` are stored as snapshots, and matchers are pure functions, scores can be recomputed without re-running `generate`.

**Workflow**: You notice an expected value is wrong in an example YAML file.  You fix it.  Then:

1. **CLI**: `mise eval <name> --rescore` rescores **all runs** for that eval.  The UI provides a "Rescore" button on individual runs for more targeted rescoring.
2. The engine loads the updated expected values from disk, re-runs the matcher against the stored `output` for each example in the targeted run(s), and updates the `score_tree`, `score`, and `expected` columns on the affected `eval_run_examples` rows.
3. The `updated_at` on the affected runs is set.

This avoids paying for another LLM call just to see if fixing an expected value improves the score.  Because latest and checkpoint scores are computed dynamically, they automatically reflect the updated per-example scores.


## Score Trees

A score tree mirrors the shape of the output type but contains **only scores** — no actual or expected values (those are stored separately in `eval_run_examples`).

### Format

Every node is a JSON object with a `score` key (float, 0.0 to 1.0).  Interior nodes also have a `children` key.

**Leaf node** (primitive value):
```json
{ "score": 1.0 }
```

**Hash node** (fixed-key object):
```json
{
  "score": 0.85,
  "children": {
    "name": { "score": 1.0 },
    "price": { "score": 0.7 }
  }
}
```

The hash node's `score` is the weighted average of its children (weights come from the `weight:` option on each field in the `output_type` declaration, defaulting to 1).

**Array node** (ordered):
```json
{
  "score": 0.67,
  "children": [
    { "score": 1.0 },
    { "score": 0.0 },
    { "score": 1.0 }
  ]
}
```

The array node's `score` is the arithmetic mean of its children.  Children correspond to elements by index — `children[0]` scores `actual[0]` vs `expected[0]`.  If the arrays have different lengths, missing elements score 0.0 (a child is created for each index up to `max(actual.length, expected.length)`).

**Array node** (unordered — includes alignment info):
```json
{
  "score": 0.5,
  "alignment": [
    { "expected": 0, "actual": 1 },
    { "expected": 1, "actual": null },
    { "expected": 2, "actual": 0 },
    { "expected": null, "actual": 2 }
  ],
  "children": [
    { "score": 1.0 },
    { "score": 0.0 },
    { "score": 1.0 },
    { "score": 0.0 }
  ]
}
```

The `alignment` array has one entry per child, explaining what was compared.  Each entry maps an expected index to an actual index:

- `{ "expected": 0, "actual": 1 }` — expected item 0 was matched with actual item 1.
- `{ "expected": 1, "actual": null }` — expected item 1 had no match in actual (missing).
- `{ "expected": null, "actual": 2 }` — actual item 2 had no match in expected (extra).

Missing and extra items score 0.0.  The `alignment` key is only present on unordered collections.  It gives the UI everything it needs to draw paired diffs between actual and expected without re-running the alignment logic.

### Design rationale

Actual and expected values are stored as full primitive-data structures in their own columns.  The score tree is a separate, parallel structure containing only scores.  This means:

- Each piece of data is stored once, in its natural form — actual and expected are guaranteed to be the same primitive types that went in.
- Score trees are trivially JSON-serializable — just nested hashes with `score` and `children` keys.
- Recomputing scores means re-running the matcher and replacing only the `score_tree` column.
- The UI can render actual/expected side-by-side and overlay scores from the tree without untangling interleaved data.


## Types and Matching (DSL Syntax Under Discussion)

> **Status**: The core idea — unifying output type declaration and matching strategy into a single `output_type` declaration — is decided.  The exact DSL syntax and whether to use an existing library are still under discussion.  The rest of the plan assumes `output_type` exists and works as described here; only the surface syntax may change.

### The goal

Declare the output shape once, with matching annotations.  This single declaration drives both **shape validation** (of examples and outputs) and **matcher generation** (no separate matcher definition needed):

```ruby
class ProductNameEval < EvalEngine::Eval
  output_type :hash do
    field :name, :string, match: :soft
    field :price, :float, tolerance: 0.01
    field :tags, :array, of: :string, order: :unordered, key: :itself
    field :is_verified, :boolean
  end

  def generate(input)
    # ...
  end
end
```

### Primitive types and their matching options

| Type       | Default match | Options                              |
|-----------|---------------|--------------------------------------|
| `:string`  | `:exact`      | `match: :soft` (cosine similarity), `match: :exact` |
| `:integer` | `:exact`      | `tolerance: N`                       |
| `:float`   | `:exact`      | `tolerance: N`                       |
| `:boolean` | `:exact`      | —                                    |

All types support `weight: N` for importance tuning within their parent hash.

### Compound types

| Type    | Options                                         |
|---------|------------------------------------------------|
| `:hash` | Block with `field` declarations                 |
| `:array`| `of: <type>`, `order: :ordered / :unordered`, `key: <proc or symbol>` |

**Hash keys**: Field names are declared as symbols in the DSL (e.g., `field :name, :string`), but matching is **string-key-indifferent by default** — `{ "name" => "Blix" }` and `{ name: "Blix" }` are treated as equivalent.  This is because YAML/JSON deserialization produces string keys while most Ruby APIs use symbols.  Indifference can be turned off per-hash if strict key-type matching is ever needed.

**Unordered arrays** require a `key:` option that determines how elements are aligned between actual and expected.  The key function extracts an identity value from each element:

- `key: :itself` — the element itself is the key (useful for arrays of strings or numbers).
- `key: :name` — shorthand for `key: ->(el) { el["name"] }`, extracts a hash field.
- `key: ->(el) { el["id"] }` — arbitrary lambda for complex keys.

Alignment works by building a lookup from key → element for both actual and expected, then matching by key.  Duplicate keys within the same array are an error.

### Named data types

The inline `output_type :hash do ... end` form is convenient for one-off evals, but for complex or reusable output shapes, you can define a named class inheriting from `EvalEngine::DataType`:

```ruby
class ProductResult < EvalEngine::DataType
  field :name, :string, match: :soft
  field :price, :float, tolerance: 0.01
  field :is_verified, :boolean
end

class ProductNameEval < EvalEngine::Eval
  output_type ProductResult

  def generate(input)
    # Can return a ProductResult instance (which provides typed accessors)
    # or a plain hash — both are accepted and validated against the same shape.
    ProductResult.new(name: result.name, price: result.price, is_verified: true)
  end
end
```

`EvalEngine::DataType` handles `to_primitive` / `from_primitive` automatically — instances serialize to plain hashes for storage and deserialize back for display.  The inline `output_type :hash do ... end` form is effectively sugar for an anonymous `DataType`.  This progression (inline → named class) means starting simple doesn't preclude moving to typed classes later.

### Escape hatch: custom matchers

For cases that don't fit the DSL (e.g., domain-specific scoring logic), provide a custom matcher:

```ruby
class ImageSetEval < EvalEngine::Eval
  output_type :custom, matcher: WeightedImageSetMatcher.new

  def generate(input)
    # ...
  end
end
```

Custom matchers must implement `match(actual, expected) → score_tree_hash` where the return value is a hash in the score tree JSON format described above.  They must be pure functions (no side effects, no external state).  Shape validation is skipped for custom matchers — the matcher is responsible for handling whatever shapes it receives.

### Open questions

- **Library**: A lightweight custom DSL (no dependencies) vs. building on `dry-types`.  Current leaning: custom DSL — our type system is very constrained (primitives + hashes + arrays), and a dependency adds complexity we don't need.  Can adopt `dry-types` later if the type system grows.
- **Nested hashes**: Does `field :address, :hash do ... end` nest naturally?
- **Nilable fields**: Syntax for optional fields.  Perhaps `field :middle_name, :string, optional: true`.


## Matchers (Built-in Set)

These are the default matchers, derived automatically from `output_type` declarations.  They can also be used directly when building custom matchers.

### Leaf matchers

- **Exact**: Score 1.0 if values are equal, 0.0 otherwise.  Default for all types.
- **Soft string**: Computes text similarity between two strings using embedding vectors.  The embedding function is provided by the host application via `EvalEngine.configure { |c| c.embedding_fn = ->(text) { ... } }`.  Score is the cosine similarity of the two embeddings (0.0 to 1.0).  Score 0.0 if either value is nil.  Embedding calls are slow, which is a key reason score trees are stored in the database rather than recomputed on every view.
- **Numeric with tolerance**: Score 1.0 if the absolute difference is within tolerance.  Beyond tolerance, score degrades linearly from 1.0 toward 0.0.  The exact degradation formula is an implementation detail, but the principle is: small overages lose few points, large overages lose many.  Score 0.0 if either value is nil or non-numeric.

### Collection matchers

- **Hash matcher**: Runs the child matcher for each declared field.  The hash node's score is the weighted average of its children's scores (weights come from the `weight:` option on each field, defaulting to 1).  String-key-indifferent by default.
- **Ordered array matcher**: Matches elements by index.  The array node's score is the arithmetic mean of its children's scores.  Missing/extra elements score 0.0.
- **Unordered array matcher**: Aligns elements by key (see "Unordered arrays" above), then matches aligned pairs.  Produces alignment info in the score tree.  Unmatched expected elements score 0.0.  Extra actual elements score 0.0.

### Invariants

Matchers depend only on their `(actual, expected)` inputs and produce deterministic results for the same inputs.  Most are pure in-process computations.  The exception is **soft string matching**, which calls the configured embedding function — this is deterministic but involves external computation and may be slow.


## UI

### Index page

Lists all evals discovered under the eval root directory.  For each eval, shows:

- Eval name
- Number of examples
- Latest score (computed across most recent per-example results; see "Scoring")
- Checkpoint score (if one exists)
- Sorted alphabetically

### Individual eval page

**Run controls:**
- "Run all examples" button
- Per-example "Run" button

**Examples section** (collapsible panel):
- Lists all examples with their keys
- "Add example" button (though most examples will be added by code or CLI)
- Rich visualization of inputs/outputs where applicable (e.g., link/iframe for URLs, inline images, formatted JSON)

**Runs section** (collapsible panel):
- Reverse-chronological list of runs
- Each run shows: timestamp, duration, number of examples, per-run mean score
- Partial runs (fewer examples than total) are visually distinguished (e.g., "(3 of 12 examples)" label)
- Expandable to see per-example results: input, expected, output, score tree, error (if any)
- Actions: delete run, promote as checkpoint, rescore (re-runs matchers against stored outputs)
- Promote action: if deleting enough old runs would leave the checkpoint with incomplete example coverage, show a confirmation dialog explaining the situation

**Result view** (collapsible panel):
- Shows each example's latest result, filtered by score threshold
- Threshold slider (default: 1.0, meaning "show everything that isn't perfect")
- Each example below the threshold is displayed as a two-column tree diff:
  - Left column: expected values, expanded in YAML-like format (one line per branch/leaf)
  - Right column: actual values, same format
  - Scores displayed in the margin next to corresponding lines
  - Tree nodes are expandable/collapsible
- Examples with `status: "error"` show the error message and backtrace instead of a diff


## Backend

### Execution

- **Parallel execution**: Examples within a run execute in parallel.  Default parallelism is configurable globally and overridable per-eval.
- **Timing**: Execution time is measured per-example (`started_at` / `finished_at` on each `eval_run_example`).

### Shape validation

Each `EvalEngine::Types::Base` subclass implements two methods:

- **`validate(value) → nil | error_tree`** — pure function returning `nil` when the value is valid, or a tree-of-errors mirroring the score-tree shape (`{ "errors" => [...], "children" => {...|[...]} }`). Hash nodes report missing required fields as `{ "errors" => ["Missing required field"] }` at the absent child position. There is no syntax for optional fields yet.
- **`validate!(value)`** — calls `validate`; if it returns a tree, raises `EvalEngine::Types::ValidationError` carrying the tree on `.tree` with a flat human-readable `.message` (one error per line, dotted paths like `address.zip:` or `[2]:` prefixing each).

The runner is responsible for invoking `validate!` against examples and outputs:

- On example load (in the runner): validate each example's `input` against `input_type` and `expected` against `output_type`. Collect failures across all examples and surface them with the example file path before any `generate` is invoked.
- On generate return (in the runner): validate the return value against `output_type`. A failure becomes the example's `error`, status `error`, score 0.0.

### Module loading

The engine discovers evals by scanning the configured root directory for `<name>/<name>_eval.rb` files.  Modules are loaded dynamically at runtime using `Zeitwerk` or `load` — the less ceremony, the better.  The class name is derived from the file path by convention (`is_ebike_manufacturer_eval.rb` → `IsEbikeManufacturerEval`).


## CLI

The CLI is the primary interface for agents and automation.  Commands are defined as mise tasks (custom commands in the project's `mise.toml`).

| Command                                | Effect                                        | Cost    |
|----------------------------------------|----------------------------------------------|---------|
| `mise eval`                            | List all evals with scores                   | Free    |
| `mise eval <name>`                     | Show scores for one eval                     | Free    |
| `mise eval <name> --run`               | Run all examples                             | Costs $ |
| `mise eval <name> --run --only <key>`  | Run one example                              | Costs $ |
| `mise eval <name> --debug`             | Show per-example score details               | Free    |
| `mise eval <name> --promote`           | Set checkpoint to current datetime           | Free    |
| `mise eval <name> --rescore`           | Recompute scores against current expected    | Slow*   |

The distinction between **"free"** (comparing stored data) and **"costs $"** (invoking `generate`, which typically calls LLM APIs) is important and should be surfaced clearly in help text and UI.

\* `--rescore` does not re-run `generate` (no LLM prompt costs), but it does recompute matches — which involves embedding calls for any `match: :soft` fields.  This is slow but not expensive in the same way as a full run.


## Frontend

Client code is authored in TypeScript and built with Vite.  However, the initial implementation should lean heavily on Rails (server-rendered HTML, Turbo frames/streams) and only introduce client-side TypeScript when genuinely needed (e.g., the score threshold slider, tree expand/collapse interactions).  The goal is to get as far as possible with no custom JS.


## Deferred Decisions

- **`output_type` DSL syntax**: Finalized during implementation of the type system.  The prototype will try the `field`-based DSL shown in "Types and Matching."  If it feels awkward for simple cases (single-value outputs, flat hashes), we'll simplify before committing to it.


## Tasks

1. **Infrastructure** — Type system (with tree-shaped `validate` / raising `validate!`), matchers, configuration, Rails Engine setup, the `EvalEngine::Eval` base class, the `Example` loader, and the public Ruby API (`create_example`, `sanitize_key`, `save_file`).
2. **Database layer** — `connects_to` configuration plumbing (per "Database connection"), `EvalEngine::Record` abstract base, migrations for `eval_runs`, `eval_run_examples`, `eval_checkpoints`, and the ActiveRecord models.
3. **Runner** — the orchestrator that loads an eval, validates examples and outputs against declared types, runs examples in parallel, creates run/example rows, handles errors.
4. **Scoring queries** — the "latest score" and "checkpoint score" computations from the plan.
5. **CLI** — mise tasks wrapping the runner.
6. **UI** — Rails controllers/views for index + eval detail pages.
