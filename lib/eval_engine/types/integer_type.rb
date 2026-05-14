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
        return { "score" => 0.0 } if actual.nil? || expected.nil?
        return { "score" => 0.0 } unless actual.is_a?(Numeric) && expected.is_a?(Numeric)

        diff = (actual - expected).abs
        score =
          if diff <= @tolerance
            1.0
          elsif @tolerance > 0
            overage = diff - @tolerance
            [1.0 - (overage.to_f / @tolerance), 0.0].max
          else
            0.0
          end
        { "score" => score }
      end
    end
  end
end
