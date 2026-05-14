module EvalEngine
  class RunExample < Record
    enum :status, { passed: "passed", failed: "failed", error: "error" }

    belongs_to :run
  end
end
