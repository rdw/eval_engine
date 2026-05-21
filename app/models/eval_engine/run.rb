module EvalEngine
  class Run < Record
    enum :status, { running: "running", completed: "completed", failed: "failed" }

    has_many :run_examples, dependent: :destroy

    after_create_commit :broadcast_run_prepend
    after_update_commit :broadcast_run_replace, if: :saved_change_to_status?

    private

    def broadcast_run_prepend
      Broadcasts.broadcast_run_prepend(self)
    end

    def broadcast_run_replace
      Broadcasts.broadcast_run_replace(self)
    end
  end
end
