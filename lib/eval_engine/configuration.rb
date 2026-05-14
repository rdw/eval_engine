module EvalEngine
  class Configuration
    attr_accessor :eval_root, :embedding_fn, :parallelism

    def initialize
      @parallelism = 4
    end
  end
end
