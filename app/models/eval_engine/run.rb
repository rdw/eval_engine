module EvalEngine
  class Run < Record
    enum :status, { running: "running", completed: "completed", failed: "failed" }

    has_many :run_examples, dependent: :destroy
  end
end
