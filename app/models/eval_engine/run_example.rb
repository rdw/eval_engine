module EvalEngine
  class RunExample < Record
    enum :status, { completed: "completed", errored: "errored" }

    belongs_to :run

    after_save_commit :broadcast_example_row

    private

    def broadcast_example_row
      Broadcasts.broadcast_example_row(self)
    end
  end
end
