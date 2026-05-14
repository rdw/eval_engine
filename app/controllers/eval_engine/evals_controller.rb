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
    end

    private

    def eval_exists?(name)
      EvalEngine.discover_evals.include?(name)
    end
  end
end
