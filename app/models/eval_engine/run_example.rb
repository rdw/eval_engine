module EvalEngine
  class RunExample < Record
    enum :status, { completed: "completed", errored: "errored" }

    belongs_to :run
  end
end
