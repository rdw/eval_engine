require "yaml"

module EvalEngine
  class Example
    attr_reader :key, :input, :expected, :path

    def initialize(key:, input:, expected:, path: nil)
      @key = key
      @input = input
      @expected = expected
      @path = path
    end

    def self.load_from_file(path)
      data = YAML.safe_load(File.read(path), permitted_classes: [])
      key = File.basename(path, ".yaml")
      new(key: key, input: data["input"], expected: data["expected"], path: path)
    end

    def self.load_all(examples_dir)
      return [] unless Dir.exist?(examples_dir)

      Dir.glob(File.join(examples_dir, "*.yaml")).sort.map { |path| load_from_file(path) }
    end

    def self.examples_dir_for(eval_root, eval_name)
      File.join(eval_root, eval_name, "examples")
    end
  end
end
