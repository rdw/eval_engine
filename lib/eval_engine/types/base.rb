module EvalEngine
  module Types
    class Base
      attr_reader :weight

      def initialize(weight: 1)
        @weight = weight.to_f
      end

      def validate(_value)
        raise NotImplementedError
      end

      def validate!(value)
        tree = validate(value)
        raise ValidationError, tree if tree
      end

      def match(_actual, _expected)
        raise NotImplementedError
      end
    end
  end
end
