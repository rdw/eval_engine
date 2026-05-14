require "rails_helper"

RSpec.describe EvalEngine::Example do
  let(:tmp_dir) { Dir.mktmpdir("example_spec") }

  after { FileUtils.rm_rf(tmp_dir) }

  describe ".load_from_file" do
    it "parses YAML and extracts the key from the filename" do
      path = File.join(tmp_dir, "blixbike.yaml")
      File.write(path, YAML.dump("input" => { "url" => "https://blixbike.com/" }, "expected" => "manufacturer"))

      example = described_class.load_from_file(path)

      expect(example.key).to eq("blixbike")
      expect(example.input).to eq({ "url" => "https://blixbike.com/" })
      expect(example.expected).to eq("manufacturer")
    end

    it "stores the source path on the loaded example" do
      path = File.join(tmp_dir, "blixbike.yaml")
      File.write(path, YAML.dump("input" => {}, "expected" => "x"))

      example = described_class.load_from_file(path)

      expect(example.path).to eq(path)
    end

    it "uses safe_load and rejects symbols" do
      path = File.join(tmp_dir, "bad_symbols.yaml")
      File.write(path, "input: !ruby/sym dangerous\nexpected: ok\n")

      expect { described_class.load_from_file(path) }.to raise_error(Psych::DisallowedClass)
    end

    it "uses safe_load and rejects arbitrary objects" do
      path = File.join(tmp_dir, "bad_object.yaml")
      File.write(path, "--- !ruby/object:OpenStruct\ntable:\n  :foo: bar\n")

      expect { described_class.load_from_file(path) }.to raise_error(Psych::DisallowedClass)
    end

    it "handles nested input structures" do
      path = File.join(tmp_dir, "nested_input.yaml")
      File.write(
        path,
        YAML.dump(
          "input" => {
            "url" => "https://example.com/",
            "metadata" => {
              "source" => "test"
            }
          },
          "expected" => {
            "name" => "Example",
            "category" => "retail"
          }
        )
      )

      example = described_class.load_from_file(path)

      expect(example.input).to eq({ "url" => "https://example.com/", "metadata" => { "source" => "test" } })
      expect(example.expected).to eq({ "name" => "Example", "category" => "retail" })
    end
  end

  describe ".load_all" do
    it "loads all YAML files sorted alphabetically" do
      examples_dir = File.join(tmp_dir, "examples")
      FileUtils.mkdir_p(examples_dir)

      File.write(File.join(examples_dir, "zebra.yaml"), YAML.dump("input" => { "name" => "zebra" }, "expected" => "z"))
      File.write(File.join(examples_dir, "alpha.yaml"), YAML.dump("input" => { "name" => "alpha" }, "expected" => "a"))
      File.write(
        File.join(examples_dir, "middle.yaml"),
        YAML.dump("input" => { "name" => "middle" }, "expected" => "m")
      )

      examples = described_class.load_all(examples_dir)

      expect(examples.length).to eq(3)
      expect(examples.map(&:key)).to eq(%w[alpha middle zebra])
    end

    it "returns empty array for nonexistent directory" do
      nonexistent = File.join(tmp_dir, "does_not_exist")

      expect(described_class.load_all(nonexistent)).to eq([])
    end

    it "returns empty array for empty directory" do
      empty_dir = File.join(tmp_dir, "empty")
      FileUtils.mkdir_p(empty_dir)

      expect(described_class.load_all(empty_dir)).to eq([])
    end

    it "ignores non-YAML files" do
      examples_dir = File.join(tmp_dir, "examples")
      FileUtils.mkdir_p(examples_dir)

      File.write(
        File.join(examples_dir, "valid.yaml"),
        YAML.dump("input" => { "name" => "valid" }, "expected" => "yes")
      )
      File.write(File.join(examples_dir, "readme.txt"), "not a yaml file")
      File.write(File.join(examples_dir, "data.json"), '{"key": "value"}')

      examples = described_class.load_all(examples_dir)

      expect(examples.length).to eq(1)
      expect(examples.first.key).to eq("valid")
    end
  end

  describe ".examples_dir_for" do
    it "computes the correct path" do
      result = described_class.examples_dir_for("/data/evals", "is_ebike_manufacturer")

      expect(result).to eq("/data/evals/is_ebike_manufacturer/examples")
    end

    it "joins path components without duplicating slashes" do
      result = described_class.examples_dir_for("/data/evals/", "product_name")

      expect(result).to eq("/data/evals/product_name/examples")
    end
  end
end
