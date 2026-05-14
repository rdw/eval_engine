require "active_support/core_ext/string/inflections"

module EvalEngine
  module Loader
    class NotFoundError < StandardError
    end

    def self.load_eval(eval_name, eval_root: nil)
      eval_root ||= EvalEngine.configuration.eval_root
      file = File.join(eval_root, eval_name, "#{eval_name}_eval.rb")
      raise NotFoundError, "Eval not found: #{file}" unless File.exist?(file)

      Kernel.load(file)
      class_name = "#{eval_name.camelize}Eval"
      Object.const_get(class_name)
    end

    def self.discover(eval_root: nil)
      eval_root ||= EvalEngine.configuration.eval_root
      Dir.glob(File.join(eval_root, "*", "*_eval.rb")).map { |file| File.basename(File.dirname(file)) }.sort
    end
  end
end
