module EvalEngine
  module Types
    class StringType < Base
      def initialize(match: :exact, weight: 1)
        super(weight: weight)
        @match_strategy = match
      end

      def validate(value)
        return nil if value.nil? || value.is_a?(String)

        { "errors" => ["Expected string, got #{value.class}"] }
      end

      def match(actual, expected)
        return { "score" => 0.0 } if actual.nil? || expected.nil?

        score =
          case @match_strategy
          when :exact
            actual == expected ? 1.0 : 0.0
          when :soft
            embedding_similarity(actual.to_s, expected.to_s)
          else
            raise ArgumentError, "Unknown match strategy: #{@match_strategy}"
          end
        { "score" => score }
      end

      private

      def embedding_similarity(a, b)
        return 1.0 if a == b

        embedding_fn = EvalEngine.configuration.embedding_fn
        unless embedding_fn
          raise ConfigurationError,
                "Soft string matching requires an embedding function. " \
                  "Configure one with: EvalEngine.configure { |c| c.embedding_fn = ->(text) { ... } }"
        end

        vec_a = embedding_fn.call(a)
        vec_b = embedding_fn.call(b)
        cosine_similarity(vec_a, vec_b)
      end

      def cosine_similarity(vec_a, vec_b)
        dot_product = vec_a.zip(vec_b).sum { |a, b| a * b }
        magnitude_a = Math.sqrt(vec_a.sum { |v| v * v })
        magnitude_b = Math.sqrt(vec_b.sum { |v| v * v })

        return 0.0 if magnitude_a.zero? || magnitude_b.zero?

        (dot_product / (magnitude_a * magnitude_b)).clamp(0.0, 1.0)
      end
    end
  end
end
