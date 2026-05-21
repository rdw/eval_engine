module EvalEngine
  class RunJob < ApplicationJob
    queue_as :default

    def perform(run_id, only: nil)
      run = Run.find_by(id: run_id)
      return unless run&.running?

      eval_class = Loader.load_eval(run.eval_name)
      Runner.new(eval_class: eval_class, only: only).execute!(run)
    rescue StandardError
      run.update!(status: :failed, finished_at: Time.current) if run&.running?
      raise
    end
  end
end
