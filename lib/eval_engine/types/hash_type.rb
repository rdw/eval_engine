module EvalEngine
  module Types
    class HashType < Base
      attr_reader :fields

      def initialize(fields: {}, indifferent: true, weight: 1)
        super(weight: weight)
        @fields = fields
        @indifferent = indifferent
      end

      def validate(value)
        return nil if value.nil?
        return { "errors" => ["Expected hash, got #{value.class}"] } unless value.is_a?(Hash)

        child_errors = {}
        @fields.each do |name, type|
          if field_present?(value, name)
            sub = type.validate(indifferent_get(value, name))
            child_errors[name.to_s] = sub if sub
          else
            child_errors[name.to_s] = { "errors" => ["Missing required field"] }
          end
        end

        return nil if child_errors.empty?

        { "children" => child_errors }
      end

      def match(actual, expected)
        actual_hash = actual.is_a?(Hash) ? actual : {}
        expected_hash = expected.is_a?(Hash) ? expected : {}

        children = {}
        total_weight = 0.0
        weighted_sum = 0.0

        @fields.each do |name, type|
          a = indifferent_get(actual_hash, name)
          e = indifferent_get(expected_hash, name)
          child_result = type.match(a, e)
          children[name.to_s] = child_result
          total_weight += type.weight
          weighted_sum += child_result["score"] * type.weight
        end

        score = total_weight > 0 ? weighted_sum / total_weight : 1.0
        { "score" => score, "children" => children }
      end

      private

      def field_present?(hash, name)
        return false unless hash.is_a?(Hash)
        return true if hash.key?(name)
        return true if @indifferent && name.is_a?(Symbol) && hash.key?(name.to_s)
        return true if @indifferent && name.is_a?(String) && hash.key?(name.to_sym)

        false
      end

      def indifferent_get(hash, key)
        return nil unless hash.is_a?(Hash)
        return hash[key] if hash.key?(key)
        return hash[key.to_s] if @indifferent && key.is_a?(Symbol)
        return hash[key.to_sym] if @indifferent && key.is_a?(String)

        nil
      end
    end
  end
end
