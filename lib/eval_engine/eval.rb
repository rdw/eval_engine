require "active_support/core_ext/string/inflections"

module EvalEngine
  class Eval
    class << self
      def output_type(type_name = nil, **options, &block)
        if type_name.nil?
          @output_type
        else
          @output_type = Types.build(type_name, **options, &block)
        end
      end

      def input_type(type_name = nil, **options, &block)
        if type_name.nil?
          @input_type
        else
          @input_type = Types.build(type_name, **options, &block)
        end
      end

      def eval_name
        name.demodulize.underscore.delete_suffix("_eval")
      end
    end

    def initialize(eval_root: nil)
      @eval_root = eval_root || EvalEngine.configuration.eval_root
    end

    def eval_dir
      File.join(@eval_root, self.class.eval_name)
    end

    def files_path(relative_path = "")
      File.join(eval_dir, "files", relative_path)
    end

    def read_file(relative_path)
      File.read(files_path(relative_path))
    end

    def generate(_input)
      raise NotImplementedError, "#{self.class.name} must implement #generate"
    end
  end
end
