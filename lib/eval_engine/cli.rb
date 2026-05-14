require "thor"

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
  end
end
