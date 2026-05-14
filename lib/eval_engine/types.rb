require_relative "types/validation_error"
require_relative "types/base"
require_relative "types/string_type"
require_relative "types/integer_type"
require_relative "types/float_type"
require_relative "types/boolean_type"
require_relative "types/hash_type"
require_relative "types/array_type"
require_relative "types/custom_type"
require_relative "types/hash_type_builder"

module EvalEngine
  module Types
    def self.build(type_name, **options, &block)
      case type_name
      when :hash
        build_hash(**options, &block)
      when :array
        build_array(**options, &block)
      when :custom
        CustomType.new(**options)
      when Symbol
        build_primitive(type_name, **options)
      else
        raise ArgumentError, "Unknown type: #{type_name.inspect}"
      end
    end

    def self.build_hash(**options, &block)
      if block
        builder = HashTypeBuilder.new
        builder.instance_eval(&block)
        builder.build(**options)
      else
        HashType.new(**options)
      end
    end

    def self.build_array(**options, &block)
      of = options.delete(:of)
      raise ArgumentError, "Array type requires an :of option" unless of

      element_options = options.delete(:element_options) || {}
      element_type = build(of, **element_options, &block)
      ArrayType.new(element_type: element_type, **options)
    end

    def self.build_primitive(type_name, **options)
      case type_name
      when :string
        StringType.new(**options)
      when :integer
        IntegerType.new(**options)
      when :float
        FloatType.new(**options)
      when :boolean
        BooleanType.new(**options)
      else
        raise ArgumentError, "Unknown type: #{type_name}"
      end
    end

    private_class_method :build_hash, :build_array, :build_primitive
  end
end
