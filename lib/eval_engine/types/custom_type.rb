module EvalEngine
  module Types
    class CustomType < Base
      def initialize(matcher:, weight: 1)
        super(weight: weight)
        @matcher = matcher
      end

      def validate(_value)
        nil
      end

      def match(actual, expected)
        @matcher.match(actual, expected)
      end
    end
  end
end
