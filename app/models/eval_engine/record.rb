module EvalEngine
  class Record < ::ActiveRecord::Base
    self.abstract_class = true

    connects_to(**EvalEngine.connects_to) if EvalEngine.connects_to
  end
end
