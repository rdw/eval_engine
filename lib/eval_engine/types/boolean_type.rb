module EvalEngine
  module Types
    class BooleanType < Base
      def validate(value)
        return nil if value.nil? || value == true || value == false

        { "errors" => ["Expected boolean, got #{value.class}"] }
      end

      def match(actual, expected)
        { "score" => actual == expected ? 1.0 : 0.0 }
      end
    end
  end
end
