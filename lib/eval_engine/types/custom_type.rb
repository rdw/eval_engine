module EvalEngine
  module Types
    class CustomType < Base
      attr_reader :matcher

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

      def diff_partial_path
        return @matcher.diff_partial_path if @matcher.respond_to?(:diff_partial_path)

        super
      end
    end
  end
end
