# EvalEngine

A Rails engine for authoring and running LLM evaluations.  Evals live as plain Ruby classes with YAML examples on disk; runs and per-example results are stored in the database for history and rescoring.

## Installation

In your host application's `Gemfile`:

```ruby
gem "eval_engine", path: "../eval_engine"   # or git: ..., or rubygems
```

Then:

```bash
bundle install
bundle binstubs eval_engine                       # creates bin/eval-cli
bin/rails eval_engine:install:migrations          # copies migrations into db/migrate
bin/rails db:migrate
```

The `bundle binstubs eval_engine` step is easy to forget — without it, `bin/eval-cli` won't exist (only `bundle exec eval-cli` will work).

## Quick start

Author an eval at `eval/<name>/<name>_eval.rb`:

```ruby
class IsErrorLogEval < EvalEngine::Eval
  input_type :hash do
    field :url, :string
  end

  output_type :string, match: :exact

  def generate(input)
    # call your prompt / model / classifier here
  end
end
```

Drop one example per file under `eval/<name>/examples/`:

```yaml
# eval/is_error_log/examples/log_123.yaml
input:
  url: "https://example.com/logs/123.log"
expected: "warning"
```

Run it:

```bash
bin/eval-cli list                                    # lists discovered evals
bin/eval-cli run is_error_log                        # runs all examples
bin/eval-cli run is_error_log --only log_123         # runs a subset
bin/eval-cli promote is_error_log                    # snapshot current scores as the checkpoint
```

See [`docs/plans/2026-05-13-Eval-Engine.md`](docs/plans/2026-05-13-Eval-Engine.md) for the full design.

## Configuration

In an initializer (e.g. `config/initializers/eval_engine.rb`):

```ruby
EvalEngine.configure do |c|
  c.eval_root    = Rails.root.join("eval").to_s   # default
  c.parallelism  = 4                              # default
  c.embedding_fn = ->(text) { ... }               # required for `match: :soft` string fields
end
```

## Storing eval data in a separate database

Eval data (runs, examples, checkpoints) can live in its own database — useful when you want to keep eval history out of your primary DB's backups, replication, or schema dumps.

This is two manual setup steps plus the migration install:

### 1. Configure the second database in `config/database.yml`

```yaml
production:
  primary:
    database: app_production
    migrations_paths: db/migrate
  evals:
    database: app_evals_production
    migrations_paths: db/evals_migrate
```

### 2. Tell EvalEngine to connect to it

In `config/environments/production.rb`:

```ruby
config.eval_engine.connects_to = { database: { writing: :evals } }
```

(Equivalently, `EvalEngine.connects_to = { database: { writing: :evals } }` in an initializer.)

When unset, EvalEngine's models fall through to the host's default connection — so simple apps need no extra configuration.

## Live UI updates (Action Cable)

Runs from the web UI are enqueued as background jobs and broadcast per-example progress to the eval show page via Turbo Streams. This relies on Action Cable being available in the host app, which is the Rails default — usually nothing to configure. Three host requirements to be aware of:

- Action Cable must not be disabled (it's enabled by default in every Rails 5.0+ app).
- `config.action_cable.allowed_request_origins` must accept the host's own origin in non-development environments. Most hosts already set this for any cable-using feature; if no other feature uses cable, add the host's URL to that allowlist.
- **The cable adapter must bridge processes if your job worker runs separately from your web server.** This is the most common gotcha. The Rails default `cable.yml` uses `adapter: async` for development, which is in-process pubsub only: a broadcast made in a SolidQueue/Sidekiq worker process never reaches the web process subscribers, so the page subscribes successfully but receives nothing. If you run any out-of-process worker (including SolidQueue in development), switch the cable adapter to one of:
  - **Solid Cable** — `gem "solid_cable"`, `bin/rails solid_cable:install`, then `adapter: solid_cable` in `cable.yml`. Postgres/MySQL/SQLite-based; no extra infrastructure.
  - **Redis** — `adapter: redis` in `cable.yml` with a Redis URL. Battle-tested.

  The web-process `async` adapter only works end-to-end if jobs also run in the web process (the default `:async` ActiveJob adapter, or `perform_now` paths like specs).

For background-job durability in production, configure a real queue adapter (SolidQueue, Sidekiq, etc.) — the default `:async` ActiveJob adapter runs jobs in the web process and loses them on restart.

### 3. Install migrations into the second database's path

```bash
bin/rails eval_engine:install:migrations MIGRATIONS_PATH=db/evals_migrate
bin/rails db:migrate:evals
```

The `MIGRATIONS_PATH` override on the install task is specific to this engine — it skips the multi-DB `database.yml` lookup that Rails' default install task uses, so you can install migrations before (or independently of) configuring the second database.

## Development

```bash
mise install                # bootstrap toolchain
mise rspec                  # run tests
mise ci                     # rubocop + tests
mise prettier               # format
```

Tests use a SQLite dummy app at `spec/dummy/`.  Migrations are run automatically at spec boot.

## License

MIT.
