module EvalEngine
  module Types
    class HashTypeBuilder
      def initialize
        @fields = {}
      end

      def field(name, type, **options, &block)
        @fields[name] = Types.build(type, **options, &block)
      end

      def build(**options)
        HashType.new(fields: @fields, **options)
      end
    end
  end
end
