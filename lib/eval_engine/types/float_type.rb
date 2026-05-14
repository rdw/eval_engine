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
        return { "score" => 0.0 } if actual.nil? || expected.nil?
        return { "score" => 0.0 } unless actual.is_a?(Numeric) && expected.is_a?(Numeric)

        diff = (actual - expected).abs.to_f
        score =
          if diff <= @tolerance
            1.0
          elsif @tolerance > 0
            overage = diff - @tolerance
            [1.0 - (overage / @tolerance), 0.0].max
          else
            actual == expected ? 1.0 : 0.0
          end
        { "score" => score }
      end
    end
  end
end
