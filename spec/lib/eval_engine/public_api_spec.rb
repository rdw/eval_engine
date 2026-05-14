require "rails_helper"

RSpec.describe EvalEngine do
  let(:tmp_dir) { Dir.mktmpdir("public_api_spec") }

  before do
    @original_eval_root = described_class.configuration.eval_root
    described_class.configuration.eval_root = tmp_dir
  end

  after do
    described_class.configuration.eval_root = @original_eval_root
    FileUtils.rm_rf(tmp_dir)
  end

  describe ".sanitize_key" do
    it "converts a URL to a filename-safe string" do
      result = described_class.sanitize_key("https://www.blixbike.com/")

      expect(result).to eq("www_blixbike_com")
    end

    it "strips the protocol" do
      http_result = described_class.sanitize_key("http://example.com")
      https_result = described_class.sanitize_key("https://example.com")

      expect(http_result).to eq("example_com")
      expect(https_result).to eq("example_com")
    end

    it "replaces non-alphanumeric characters with underscores" do
      result = described_class.sanitize_key("hello world!@#$%^&*()test")

      expect(result).to eq("hello_world_test")
    end

    it "truncates to 100 characters" do
      long_string = "a" * 200
      result = described_class.sanitize_key(long_string)

      expect(result.length).to eq(100)
    end

    it "strips leading and trailing underscores" do
      result = described_class.sanitize_key("___hello___")

      expect(result).to eq("hello")
    end

    it "downcases the input" do
      result = described_class.sanitize_key("LOUD-URL.COM")

      expect(result).to eq("loud_url_com")
    end

    it "handles a complex real-world URL" do
      result = described_class.sanitize_key("https://www.heybike.com/collections/all-e-bikes?page=2")

      expect(result).to eq("www_heybike_com_collections_all_e_bikes_page_2")
    end
  end

  describe ".create_example" do
    it "creates a YAML file at the correct path" do
      key =
        described_class.create_example(
          "is_ebike_manufacturer",
          "https://blixbike.com/",
          input: {
            "url" => "https://blixbike.com/"
          },
          expected: "manufacturer"
        )

      expected_path = File.join(tmp_dir, "is_ebike_manufacturer", "examples", "#{key}.yaml")
      expect(File.exist?(expected_path)).to be true
    end

    it "returns the sanitized key" do
      key =
        described_class.create_example(
          "test_eval",
          "https://example.com/page",
          input: {
            "url" => "https://example.com/page"
          },
          expected: "result"
        )

      expect(key).to eq("example_com_page")
    end

    it "produces a file loadable with YAML.safe_load" do
      key =
        described_class.create_example(
          "test_eval",
          "test_key",
          input: {
            "url" => "https://example.com/"
          },
          expected: "retailer"
        )

      file_path = File.join(tmp_dir, "test_eval", "examples", "#{key}.yaml")
      data = YAML.safe_load(File.read(file_path), permitted_classes: [])

      expect(data["input"]).to eq({ "url" => "https://example.com/" })
      expect(data["expected"]).to eq("retailer")
    end

    it "creates the examples directory if it does not exist" do
      described_class.create_example("new_eval", "first_example", input: { "data" => "test" }, expected: "expected")

      expect(Dir.exist?(File.join(tmp_dir, "new_eval", "examples"))).to be true
    end
  end

  describe ".save_file" do
    it "writes content to the correct path" do
      path = described_class.save_file("my_eval", "page.html", "<h1>Test</h1>")

      expect(path).to eq(File.join(tmp_dir, "my_eval", "files", "page.html"))
      expect(File.read(path)).to eq("<h1>Test</h1>")
    end

    it "creates parent directories as needed" do
      path = described_class.save_file("my_eval", "subdir/deep/file.txt", "content")

      expect(File.exist?(path)).to be true
      expect(File.read(path)).to eq("content")
    end

    it "overwrites existing files" do
      described_class.save_file("my_eval", "data.txt", "original")
      described_class.save_file("my_eval", "data.txt", "updated")

      path = File.join(tmp_dir, "my_eval", "files", "data.txt")
      expect(File.read(path)).to eq("updated")
    end
  end

  describe ".configure" do
    it "sets eval_root via the configuration block" do
      described_class.configure { |config| config.eval_root = "/custom/eval/path" }

      expect(described_class.configuration.eval_root).to eq("/custom/eval/path")
    end

    it "yields a Configuration object" do
      described_class.configure { |config| expect(config).to be_a(EvalEngine::Configuration) }
    end
  end

  describe ".configuration" do
    it "returns the same configuration instance across calls" do
      config1 = described_class.configuration
      config2 = described_class.configuration

      expect(config1).to equal(config2)
    end
  end
end
