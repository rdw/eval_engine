# Async runs with Turbo Streams

Per-example progress in the browser instead of a synchronous request that blocks until the whole eval finishes.

## Why

Today `POST /eval_engine/:name/runs` calls `EvalEngine.run` inline. For a 4-example eval this is fine; for a 50-example LLM-backed eval the browser holds the connection for minutes and shows nothing until done. The Runner already supports per-example streaming — it accepts an `on_example_finished` block, which the CLI uses to print status lines as they land. We want the eval show page to consume that same stream.

## Shape of the change

- `POST /eval_engine/:name/runs` becomes redirect-fast: validate, create a `Run` row in `:running`, enqueue `EvalEngine::RunJob`, redirect with a "Run started" flash.
- The job loads the existing Run and executes its examples. Each finished `RunExample` broadcasts a Turbo Stream that replaces its row in the Examples table. When the Run finishes, a final broadcast updates the Recent runs row.
- The eval show page subscribes to two streams keyed by `eval_name`: one for per-example updates, one for the Recent runs table.

## Runner contract

Split today's monolithic `Runner#run!` into two steps. The same constructor args as today (`eval_class:`, `only:`, `eval_root:`, `parallelism:`) flow through both.

- `Runner.new(...).start!` — loads the eval, validates examples (raises `ExamplesInvalid` on failure), creates the `Run` row in `:running`. Returns the Run.
- `Runner.new(...).execute!(run, &on_example_finished)` — runs each example on an existing Run, invokes the callback per example, transitions the Run to `:completed` or `:failed`.

`EvalEngine.run(...)` (used by the CLI) keeps working synchronously by calling `start!` then `execute!` in sequence with the same Runner instance. The web "Run all" and per-row "Run" buttons both go through the new async flow — the controller does `start!` (so validation errors surface immediately in the response), then enqueues a job that calls `execute!`. There is no sync code path through the controller; "Run" of a single example is async too.

## Job

`EvalEngine::RunJob.perform(run_id, only:)`:
- Loads the Run; returns early if it's no longer `:running` (e.g. someone deleted it).
- Calls `Runner.execute!(run, only: only)` with no block — model-level broadcasts handle the UI stream.
- Rescues unexpected exceptions and transitions the Run to `:failed`.

Default queue adapter is whatever Rails ships (`:async` in dev/test, host-configured in prod). Document that hosts should run a real worker (SolidQueue, Sidekiq) in production so runs survive process restarts.

## Broadcasting

Model-level, narrow targets:

- `RunExample after_save_commit` broadcasts a **replace** of `dom_id(:eval_engine_example_row, example_key)` to `[run.eval_name, "examples"]`. The partial re-renders the table row using the same helpers as the eval show page. Because the table shows "latest per example," the just-finished RunExample naturally becomes that row's content.
- `Run after_create_commit` broadcasts a **prepend** to `[eval_name, "runs"]` for the new Recent-runs row.
- `Run after_update_commit` (only when `status` changed) broadcasts a **replace** of `dom_id(run)` to `[eval_name, "runs"]` so the status pill / duration / mean update when it finishes.

### Which views subscribe

Only the **eval show page in its default ("latest") view** subscribes. Every other view is read-once and requires a manual refresh to see new activity:

- **Eval show page with `?run_id=X`** — historical view, no subscription. Broadcasts would clobber the user's pinned-run data if they arrived. Clicking "Run" on a row from this view still works: the controller redirects to `eval_path(eval_name)` without `run_id`, landing the user on the live view of the freshly-enqueued run.
- **Per-example show page (`/examples/:key`), default and `?run_id=X`** — does not subscribe at all in v1. The page is read-once. This is a deliberate scope cut: the per-example page is for after-the-fact analysis, and adding live updates there means a per-example stream (`[eval_name, example_key]`), a second broadcast target on `RunExample`, and replacing both the diff section and the history table — more moving parts than v1 warrants. Future task if it proves useful.

**Concurrent runs of the same eval** (e.g. "Run all" followed by a per-row "Run") both broadcast to the same `[eval_name, "examples"]` stream. Last-write-wins on each example row is acceptable — the broadcasts are idempotent replacements of small rows, and divergent results from concurrent jobs are an existing race we don't worsen here. Note that "last-write-wins" applies at the *server*: client arrival order over the WebSocket isn't strictly guaranteed, so if two jobs touch the same example_key within milliseconds the row might briefly show the older result. Not worth a per-Run frame.

## View changes

- Add `<%= turbo_stream_from @eval_name, "examples" %>` and `<%= turbo_stream_from @eval_name, "runs" %>` to the eval show page, but only when no `?run_id` is set.
- Extract the example table row into `_example_row.html.erb`, ID'd by `dom_id(:eval_engine_example_row, row[:key])`.
- Extract the Recent-runs row into `_run_row.html.erb`, ID'd by `dom_id(run)`.

## Self-contained Turbo + Action Cable

The engine carries Turbo into a host that doesn't already use it, but it relies on Action Cable being available — which it is by default in every Rails 5.0+ app. We don't try to mount our own cable server (Action Cable is a process-singleton; there's no "second one"):

- Add `turbo-rails` as a runtime dependency in `eval_engine.gemspec`.
- The engine's application layout renders `<%= turbo_include_tags %>` (helper from turbo-rails — emits the Turbo JS and the `action-cable-url` meta tag pointing at the host's cable mount, default `/cable`).
- README documents two host requirements: Action Cable must not be disabled, and `config.action_cable.allowed_request_origins` must accept the host's own origin (this is the default in dev; production hosts already configure it for any cable-using feature).

Hosts that already use Turbo end up with the JS loaded twice on engine pages — harmless, and means engine pages don't depend on host layout choices.

## Test strategy

- `RunsController#create` request spec switches from "asserts the run completed inline" to `have_enqueued_job(EvalEngine::RunJob)` + redirect assertion.
- New job spec runs `perform_now` and asserts broadcasts via `have_broadcasted_to([eval_name, "examples"]).from_channel(Turbo::StreamsChannel)`.
- New partial specs render `_example_row` and `_run_row` and assert their `dom_id`s.
- Existing Runner specs split along the new contract: a `start` spec (validation + row creation) and an `execute!` spec (per-example execution + status transitions). The CLI streaming spec keeps using `EvalEngine.run`.

## Out of scope (followups)

- Live updates on the per-example show page (would require a per-example stream and a second broadcast target on `RunExample`).
- Live updates on any `?run_id=` historical view.
- Cancel button on a running Run.
- Stuck-`:running` cleanup (lazy or periodic flip of abandoned runs to `:failed`).
- Live progress on the index page.
- Per-run partial mean score / errored count updating as examples land — the Recent-runs row for an in-flight run will show `status: :running` and a "—" duration/score until the final status broadcast. Acceptable for v1; the Examples table provides the live feedback.

## Tasks

1. Add `turbo-rails` to the gemspec; add `turbo_include_tags` to the engine application layout; verify a `turbo_stream_from` channel actually receives broadcasts end-to-end in the dummy app.
2. Split `Runner#run!` into `start!` + `execute!`; keep `EvalEngine.run` and the CLI working.
3. Add `EvalEngine::RunJob`; switch `RunsController#create` to `start!` + enqueue + redirect.
4. Add model-level broadcasts on `RunExample` (`after_save_commit`) and `Run` (`after_create_commit`, `after_update_commit` on `status`).
5. Extract `_example_row` and `_run_row` partials with `dom_id`s; add the two `turbo_stream_from` lines to the eval show page (latest view only).
6. Rewrite the affected request spec; add the job and partial specs.
