module EvalEngine
  class ExamplesController < ApplicationController
    def show
      @eval_name = params[:name]
      @example_key = params[:key]
      return render plain: "Eval not found: #{@eval_name}", status: :not_found unless eval_exists?(@eval_name)

      @example = find_example(@eval_name, @example_key)
      return render plain: "Example not found: #{@example_key}", status: :not_found unless @example

      @history = history_for(@eval_name, @example_key)
      @selected = pick_selected_run_example(@history, params[:run_id])
      return if @selected || params[:run_id].blank?

      render plain: "Run not found for this example: #{params[:run_id]}", status: :not_found
    end

    private

    def eval_exists?(name)
      EvalEngine.discover_evals.include?(name)
    end

    def find_example(eval_name, key)
      dir = Example.examples_dir_for(EvalEngine.configuration.eval_root, eval_name)
      Example.load_all(dir).find { |ex| ex.key == key }
    end

    def pick_selected_run_example(history, run_id)
      return history.find { |re| re.run_id.to_s == run_id.to_s } if run_id.present?

      history.find { |re| re.finished_at.present? }
    end

    def history_for(eval_name, key)
      RunExample
        .joins(:run)
        .where(eval_engine_runs: { eval_name: eval_name }, example_key: key)
        .order(started_at: :desc)
        .limit(20)
        .includes(:run)
    end
  end
end
