module EvalEngine
  class EvalsController < ApplicationController
    SORTABLE_EXAMPLE_COLUMNS = %w[key status score duration last_run_at].freeze

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

      examples = Example.load_all(Example.examples_dir_for(EvalEngine.configuration.eval_root, @eval_name))
      @latest = EvalEngine.latest_score(@eval_name)
      @checkpoint = EvalEngine.checkpoint_score(@eval_name)
      @runs = Run.where(eval_name: @eval_name).order(started_at: :desc).limit(20)
      @checkpoint_record = Checkpoint.find_by(eval_name: @eval_name)

      latest_by_key = @latest.per_example.index_by(&:example_key)
      @sort_column = SORTABLE_EXAMPLE_COLUMNS.include?(params[:sort]) ? params[:sort] : "key"
      @sort_direction = params[:dir] == "desc" ? "desc" : "asc"
      @example_rows = sort_example_rows(build_example_rows(examples, latest_by_key), @sort_column, @sort_direction)
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

    def build_example_rows(examples, latest_by_key)
      examples.map do |example|
        latest = latest_by_key[example.key]
        {
          example: example,
          latest: latest,
          key: example.key,
          status: latest&.status || "missing",
          score: latest&.score,
          duration: example_seconds(latest),
          last_run_at: latest&.finished_at
        }
      end
    end

    def example_seconds(run_example)
      return nil unless run_example&.started_at && run_example&.finished_at

      run_example.finished_at - run_example.started_at
    end

    def sort_example_rows(rows, column, direction)
      with_value, without_value = rows.partition { |row| !row[column.to_sym].nil? }
      with_value.sort_by! { |row| sortable_value(row[column.to_sym]) }
      with_value.reverse! if direction == "desc"
      with_value + without_value
    end

    def sortable_value(value)
      value.is_a?(Time) ? value.to_f : value
    end
  end
end
