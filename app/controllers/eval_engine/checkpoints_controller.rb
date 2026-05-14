module EvalEngine
  class CheckpointsController < ApplicationController
    def create
      eval_name = params[:name]
      checkpointed_at = resolve_checkpointed_at(eval_name, params[:run_id])

      checkpoint = Checkpoint.find_or_initialize_by(eval_name: eval_name)
      checkpoint.update!(checkpointed_at: checkpointed_at)

      redirect_to eval_path(eval_name), notice: "Checkpoint set to #{checkpointed_at.iso8601}."
    end

    private

    def resolve_checkpointed_at(eval_name, run_id)
      return Time.current if run_id.blank?

      run = Run.where(eval_name: eval_name).find(run_id)
      run.finished_at || Time.current
    end
  end
end
