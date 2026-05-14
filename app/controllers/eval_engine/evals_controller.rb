module EvalEngine
  class EvalsController < ApplicationController
    def index
      @evals =
        EvalEngine.discover_evals.map do |name|
          latest = EvalEngine.latest_score(name)
          checkpoint = EvalEngine.checkpoint_score(name)
          { name: name, latest: latest, checkpoint: checkpoint }
        end
    end

    def show
      @eval_name = params[:name]
      return render plain: "Eval not found: #{@eval_name}", status: :not_found unless eval_exists?(@eval_name)

      @examples = Example.load_all(Example.examples_dir_for(EvalEngine.configuration.eval_root, @eval_name))
      @latest = EvalEngine.latest_score(@eval_name)
      @checkpoint = EvalEngine.checkpoint_score(@eval_name)
      @runs = Run.where(eval_name: @eval_name).order(started_at: :desc).limit(20)
      @latest_results_by_key = @latest.per_example.index_by(&:example_key)
      @checkpoint_record = Checkpoint.find_by(eval_name: @eval_name)
    end

    def rescore
      eval_name = params[:name]
      return redirect_to(root_path, alert: "Eval not found: #{eval_name}") unless eval_exists?(eval_name)

      result = EvalEngine.rescore(eval_name)
      redirect_to eval_path(eval_name), notice: rescore_notice(result)
    end

    private

    def eval_exists?(name)
      EvalEngine.discover_evals.include?(name)
    end

    def rescore_notice(result)
      parts = ["Rescored #{result.rescored_count} rows."]
      parts << "Skipped #{result.skipped_errored} errored." if result.skipped_errored.positive?
      if result.skipped_missing_example.positive?
        parts << "Skipped #{result.skipped_missing_example} with missing examples."
      end
      parts.join(" ")
    end
  end
end
