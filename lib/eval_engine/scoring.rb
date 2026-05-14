module EvalEngine
  class Scoring
    Result = Struct.new(:mean, :per_example, :missing_keys, :as_of, keyword_init: true)

    def self.latest(eval_name)
      compute(eval_name, before: nil)
    end

    def self.at_checkpoint(eval_name)
      checkpoint = Checkpoint.find_by(eval_name: eval_name)
      return nil unless checkpoint

      compute(eval_name, before: checkpoint.checkpointed_at)
    end

    def self.compute(eval_name, before:)
      keys = on_disk_example_keys(eval_name)
      results = latest_per_example(eval_name, keys, before: before)
      mean = results.empty? ? nil : results.sum(&:score).to_f / results.size
      missing = (keys - results.map(&:example_key)).sort
      Result.new(mean: mean, per_example: results, missing_keys: missing, as_of: before)
    end

    def self.on_disk_example_keys(eval_name)
      dir = Example.examples_dir_for(EvalEngine.configuration.eval_root, eval_name)
      Example.load_all(dir).map(&:key)
    end
    private_class_method :on_disk_example_keys

    def self.latest_per_example(eval_name, keys, before:)
      return [] if keys.empty?

      candidates =
        RunExample
          .joins(:run)
          .where(eval_engine_runs: { eval_name: eval_name })
          .where(example_key: keys)
          .where.not(finished_at: nil)
      candidates = candidates.where(eval_engine_run_examples: { finished_at: ...before }) if before

      latest_ids = candidates.group(:example_key).maximum(:id).values
      RunExample.where(id: latest_ids).order(:example_key).to_a
    end
    private_class_method :latest_per_example
  end
end
