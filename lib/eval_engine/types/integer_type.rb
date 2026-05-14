module EvalEngine
  module Types
    class IntegerType < Base
      def initialize(tolerance: 0, weight: 1)
        super(weight: weight)
        @tolerance = tolerance
      end

      def validate(value)
        return nil if value.nil? || value.is_a?(Integer)

        { "errors" => ["Expected integer, got #{value.class}"] }
      end

      def match(actual, expected)
        return { "score" => actual == expected ? 1.0 : 0.0 } if actual.nil? || expected.nil?
        return { "score" => 0.0 } unless actual.is_a?(Numeric) && expected.is_a?(Numeric)

        { "score" => Types.tolerance_score((actual - expected).abs, @tolerance) }
      end
    end
  end
end
