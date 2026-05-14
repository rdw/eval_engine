require "thor"
require "json"

module EvalEngine
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "list", "List all evals discovered under the configured eval_root"
    def list
      names = EvalEngine.discover_evals
      if names.empty?
        say "No evals found under #{EvalEngine.configuration.eval_root}"
      else
        names.each { |name| say name }
      end
    end

    desc "run NAME", "Run an eval (or a subset of its examples). Costs $ — invokes generate."
    method_option :only, type: :array, banner: "KEY [KEY ...]", desc: "Run only these example keys"
    def run_eval(name)
      started_at = Time.current
      say "Running #{name}..."

      run = EvalEngine.run(name, only: options[:only]) { |example_row| say format_example_line(example_row) }

      print_run_summary(run, Time.current - started_at)
    rescue EvalEngine::Loader::NotFoundError => e
      abort_with(e.message)
    rescue EvalEngine::Runner::ExamplesInvalid => e
      abort_with("Examples failed validation:\n#{e.message}")
    end
    map "run" => :run_eval

    desc "promote NAME", "Set/update the checkpoint for NAME (defaults to now)"
    method_option :at, banner: "TIME", desc: "Checkpoint timestamp (parseable by Time.parse); defaults to now"
    def promote(name)
      at = options[:at] ? Time.parse(options[:at]) : Time.current
      checkpoint = EvalEngine::Checkpoint.find_or_initialize_by(eval_name: name)
      checkpoint.update!(checkpointed_at: at)
      say "Checkpoint for #{name}: #{checkpoint.checkpointed_at.iso8601}"
    end

    desc "show NAME", "Show latest + checkpoint scores and per-example results for an eval. Free."
    def show(name)
      latest = EvalEngine.latest_score(name)
      checkpoint = EvalEngine.checkpoint_score(name)

      say name
      say "  Latest:     #{format_score_summary(latest)}"
      say "  Checkpoint: #{format_score_summary(checkpoint, with_timestamp: true)}"
      say ""

      latest.per_example.each { |row| say format_example_line(row) }
      latest.missing_keys.each { |key| say "  #{key.ljust(EXAMPLE_KEY_WIDTH)} (not yet run)" }
    end

    desc "debug NAME", "Show per-example details (input, expected, output, score tree). Free."
    method_option :only, type: :array, banner: "KEY [KEY ...]", desc: "Show only these example keys"
    def debug(name)
      latest = EvalEngine.latest_score(name)
      rows = latest.per_example
      rows = rows.select { |r| options[:only].include?(r.example_key) } if options[:only]

      if rows.empty?
        say "No matching example results for #{name}."
        return
      end

      rows.each_with_index do |row, i|
        say "" if i.positive?
        print_example_debug(row)
      end
    end

    desc "rescore NAME",
         "Recompute scores against current expected values. Slow (re-runs matchers, may call embeddings)."
    def rescore(name)
      say "Rescoring #{name}..."
      result = EvalEngine.rescore(name)
      say "Rescored #{result.rescored_count} run examples across #{result.touched_run_ids.size} runs."
      say "Skipped #{result.skipped_errored} errored." if result.skipped_errored.positive?
      if result.skipped_missing_example.positive?
        say "Skipped #{result.skipped_missing_example} (example deleted from disk)."
      end
    rescue EvalEngine::Loader::NotFoundError => e
      abort_with(e.message)
    end

    private

    EXAMPLE_KEY_WIDTH = 30

    def format_example_line(example_row)
      key = example_row.example_key.ljust(EXAMPLE_KEY_WIDTH)
      if example_row.errored?
        first_error_line = example_row.error.to_s.lines.first.to_s.strip
        "  #{key} ERROR  #{first_error_line}"
      else
        "  #{key} #{format("%.3f", example_row.score)}"
      end
    end

    def print_run_summary(run, elapsed)
      mean_score = run.run_examples.average(:score)&.to_f
      errored_count = run.run_examples.errored.count

      summary = "Run ##{run.id} #{run.status} in #{format("%.2fs", elapsed)} (#{run.example_count} examples)."
      summary += " Mean score: #{format("%.3f", mean_score)}." if mean_score
      summary += " #{errored_count} errored." if errored_count.positive?
      say summary
    end

    def abort_with(message)
      say_error message
      exit 1
    end

    def format_score_summary(result, with_timestamp: false)
      return "(no checkpoint set)" if result.nil?

      total = result.per_example.length + result.missing_keys.length
      mean = result.mean ? format("%.3f", result.mean) : "—"
      coverage = "(#{result.per_example.length}/#{total} examples)"
      coverage += " snapshot @ #{result.as_of.iso8601}" if with_timestamp && result.as_of
      "#{mean}  #{coverage}"
    end

    def print_example_debug(row)
      score = row.errored? ? "ERROR" : format("%.3f", row.score)
      say "#{row.example_key}  #{score}"
      if row.errored?
        say "  error:"
        row.error.to_s.lines.each { |line| say "    #{line.rstrip}" }
      else
        say "  input:      #{pretty_value(row.input)}"
        say "  expected:   #{pretty_value(row.expected)}"
        say "  output:     #{pretty_value(row.output)}"
        say "  score_tree: #{pretty_value(row.score_tree)}"
      end
    end

    def pretty_value(value)
      JSON
        .pretty_generate(value)
        .lines
        .map
        .with_index { |line, i| i.zero? ? line : "              #{line}" }
        .join
        .rstrip
    end
  end
end
