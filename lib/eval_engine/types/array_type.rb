require "set"

module EvalEngine
  module Types
    class ArrayType < Base
      def initialize(element_type:, order: :ordered, key: nil, weight: 1)
        super(weight: weight)
        @element_type = element_type
        @order = order
        @key_fn = resolve_key_fn(key) if order == :unordered
      end

      def validate(value)
        return nil if value.nil?
        return { "errors" => ["Expected array, got #{value.class}"] } unless value.is_a?(Array)

        child_errors = []
        any_error = false
        value.each do |element|
          sub = @element_type.validate(element)
          child_errors << sub
          any_error = true if sub
        end

        return nil unless any_error

        { "children" => child_errors }
      end

      def match(actual, expected)
        actual_arr = actual.is_a?(Array) ? actual : []
        expected_arr = expected.is_a?(Array) ? expected : []

        case @order
        when :ordered
          match_ordered(actual_arr, expected_arr)
        when :unordered
          match_unordered(actual_arr, expected_arr)
        else
          raise ArgumentError, "Unknown order: #{@order}"
        end
      end

      private

      def match_ordered(actual_arr, expected_arr)
        max_len = [actual_arr.length, expected_arr.length].max
        children =
          (0...max_len).map do |i|
            a = i < actual_arr.length ? actual_arr[i] : nil
            e = i < expected_arr.length ? expected_arr[i] : nil
            @element_type.match(a, e)
          end

        score = children.empty? ? 1.0 : children.sum { |c| c["score"] } / children.length
        { "score" => score, "children" => children }
      end

      def match_unordered(actual_arr, expected_arr)
        actual_by_key = build_lookup(actual_arr)

        alignment = []
        children = []

        matched_actual_keys = Set.new

        expected_arr.each_with_index do |e_item, e_idx|
          e_key = @key_fn.call(e_item)
          a_entry = actual_by_key[e_key]

          if a_entry
            a_idx, a_item = a_entry
            alignment << { "expected" => e_idx, "actual" => a_idx }
            children << @element_type.match(a_item, e_item)
            matched_actual_keys << e_key
          else
            alignment << { "expected" => e_idx, "actual" => nil }
            children << { "score" => 0.0 }
          end
        end

        actual_arr.each_with_index do |a_item, a_idx|
          a_key = @key_fn.call(a_item)
          next if matched_actual_keys.include?(a_key)

          alignment << { "expected" => nil, "actual" => a_idx }
          children << { "score" => 0.0 }
        end

        score = children.empty? ? 1.0 : children.sum { |c| c["score"] } / children.length
        { "score" => score, "children" => children, "alignment" => alignment }
      end

      def build_lookup(arr)
        lookup = {}
        arr.each_with_index do |item, idx|
          key = @key_fn.call(item)
          raise DuplicateKeyError, "Duplicate key in array: #{key.inspect}" if lookup.key?(key)

          lookup[key] = [idx, item]
        end
        lookup
      end

      def resolve_key_fn(key)
        case key
        when :itself
          ->(el) { el }
        when Symbol
          ->(el) { el.is_a?(Hash) ? (el[key.to_s] || el[key]) : el.send(key) }
        when Proc
          key
        when nil
          raise ArgumentError, "Unordered arrays require a key: option"
        else
          raise ArgumentError, "Invalid key: #{key.inspect}"
        end
      end
    end
  end
end
