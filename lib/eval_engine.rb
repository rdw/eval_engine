require "fileutils"
require "yaml"
require "active_support/core_ext/module/attribute_accessors"

require "eval_engine/version"
require "eval_engine/engine"
require "eval_engine/configuration"
require "eval_engine/types"
require "eval_engine/eval"
require "eval_engine/example"

module EvalEngine
  mattr_accessor :connects_to

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def create_example(eval_name, key, input:, expected:)
      safe_key = sanitize_key(key)
      dir = File.join(configuration.eval_root, eval_name, "examples")
      FileUtils.mkdir_p(dir)
      path = File.join(dir, "#{safe_key}.yaml")
      data = { "input" => input, "expected" => expected }
      File.write(path, YAML.dump(data))
      safe_key
    end

    def sanitize_key(string)
      string.to_s.downcase.gsub(%r{https?://}, "").gsub(/[^a-z0-9]+/, "_").gsub(/\A_+|_+\z/, "").slice(0, 100)
    end

    def save_file(eval_name, relative_path, content)
      path = File.join(configuration.eval_root, eval_name, "files", relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
      path
    end
  end
end
