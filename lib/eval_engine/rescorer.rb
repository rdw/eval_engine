module EvalEngine
  class Rescorer
    Result =
      Struct.new(:rescored_count, :skipped_errored, :skipped_missing_example, :touched_run_ids, keyword_init: true)

    def self.rescore_all(eval_name, eval_root: nil)
      eval_root ||= EvalEngine.configuration.eval_root
      eval_class = Loader.load_eval(eval_name, eval_root: eval_root)
      raise ArgumentError, "#{eval_class.name} must declare an output_type" unless eval_class.output_type

      examples_by_key = Example.load_all(Example.examples_dir_for(eval_root, eval_name)).index_by(&:key)
      output_type = eval_class.output_type

      run_examples = RunExample.joins(:run).where(eval_engine_runs: { eval_name: eval_name })
      rescored = 0
      skipped_errored = 0
      skipped_missing = 0
      touched_run_ids = []

      run_examples.find_each do |re|
        if re.errored?
          skipped_errored += 1
          next
        end
        on_disk = examples_by_key[re.example_key]
        unless on_disk
          skipped_missing += 1
          next
        end

        score_tree = output_type.match(re.output, on_disk.expected)
        re.update!(expected: on_disk.expected, score_tree: score_tree, score: score_tree["score"])
        rescored += 1
        touched_run_ids << re.run_id
      end

      touched_run_ids.uniq!
      Run.where(id: touched_run_ids).update_all(updated_at: Time.current) if touched_run_ids.any?

      Result.new(
        rescored_count: rescored,
        skipped_errored: skipped_errored,
        skipped_missing_example: skipped_missing,
        touched_run_ids: touched_run_ids
      )
    end
  end
end
