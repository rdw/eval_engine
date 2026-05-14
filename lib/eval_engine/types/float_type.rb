module EvalEngine
  module Types
    class FloatType < Base
      def initialize(tolerance: 0, weight: 1)
        super(weight: weight)
        @tolerance = tolerance.to_f
      end

      def validate(value)
        return nil if value.nil? || value.is_a?(Numeric)

        { "errors" => ["Expected numeric, got #{value.class}"] }
      end

      def match(actual, expected)
        return { "score" => actual == expected ? 1.0 : 0.0 } if actual.nil? || expected.nil?
        return { "score" => 0.0 } unless actual.is_a?(Numeric) && expected.is_a?(Numeric)

        { "score" => Types.tolerance_score((actual - expected).abs.to_f, @tolerance) }
      end
    end
  end
end
