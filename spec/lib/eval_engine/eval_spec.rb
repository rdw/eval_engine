require "rails_helper"

RSpec.describe EvalEngine::Eval do
  describe ".output_type" do
    after { described_class.instance_variable_set(:@output_type, nil) }

    context "with a symbol type" do
      it "stores a StringType for :string with match option" do
        eval_class = Class.new(described_class) { output_type :string, match: :exact }

        expect(eval_class.output_type).to be_a(EvalEngine::Types::StringType)
      end

      it "stores an IntegerType for :integer" do
        eval_class = Class.new(described_class) { output_type :integer }

        expect(eval_class.output_type).to be_a(EvalEngine::Types::IntegerType)
      end

      it "stores a BooleanType for :boolean" do
        eval_class = Class.new(described_class) { output_type :boolean }

        expect(eval_class.output_type).to be_a(EvalEngine::Types::BooleanType)
      end
    end

    context "with a hash type and block" do
      it "stores a HashType with fields defined in the block" do
        eval_class =
          Class.new(described_class) do
            output_type :hash do
              field :name, :string
              field :age, :integer
            end
          end

        output_type = eval_class.output_type
        expect(output_type).to be_a(EvalEngine::Types::HashType)
        expect(output_type.fields).to have_key(:name)
        expect(output_type.fields).to have_key(:age)
        expect(output_type.fields[:name]).to be_a(EvalEngine::Types::StringType)
        expect(output_type.fields[:age]).to be_a(EvalEngine::Types::IntegerType)
      end
    end

    context "with :custom and a matcher object" do
      it "stores a CustomType wrapping the matcher" do
        matcher = double("matcher")
        eval_class = Class.new(described_class) { output_type :custom, matcher: matcher }

        expect(eval_class.output_type).to be_a(EvalEngine::Types::CustomType)
      end
    end

    context "with no arguments" do
      it "returns nil when no output_type has been set" do
        eval_class = Class.new(described_class)
        expect(eval_class.output_type).to be_nil
      end
    end
  end

  describe ".eval_name" do
    it "derives name from IsEbikeManufacturerEval" do
      stub_const("IsEbikeManufacturerEval", Class.new(described_class))
      expect(IsEbikeManufacturerEval.eval_name).to eq("is_ebike_manufacturer")
    end

    it "derives name from ProductNameEval" do
      stub_const("ProductNameEval", Class.new(described_class))
      expect(ProductNameEval.eval_name).to eq("product_name")
    end

    it "derives name from a namespaced eval class" do
      stub_const("Evals::CategoryEval", Class.new(described_class))
      expect(Evals::CategoryEval.eval_name).to eq("category")
    end
  end

  describe "#files_path" do
    it "returns the correct path within the eval directory" do
      stub_const("TestFilesEval", Class.new(described_class))
      instance = TestFilesEval.new(eval_root: "/tmp/evals")

      expect(instance.files_path).to eq("/tmp/evals/test_files/files/")
    end

    it "appends relative_path when provided" do
      stub_const("TestFilesEval", Class.new(described_class))
      instance = TestFilesEval.new(eval_root: "/tmp/evals")

      expect(instance.files_path("data.html")).to eq("/tmp/evals/test_files/files/data.html")
    end
  end

  describe "#read_file" do
    let(:tmp_dir) { Dir.mktmpdir("eval_spec") }

    after { FileUtils.rm_rf(tmp_dir) }

    it "reads a file from the files directory" do
      stub_const("ReadTestEval", Class.new(described_class))
      files_dir = File.join(tmp_dir, "read_test", "files")
      FileUtils.mkdir_p(files_dir)
      File.write(File.join(files_dir, "page.html"), "<h1>Hello</h1>")

      instance = ReadTestEval.new(eval_root: tmp_dir)
      expect(instance.read_file("page.html")).to eq("<h1>Hello</h1>")
    end
  end

  describe "#eval_dir" do
    it "returns the eval-specific directory path" do
      stub_const("MyTestEval", Class.new(described_class))
      instance = MyTestEval.new(eval_root: "/data/evals")

      expect(instance.eval_dir).to eq("/data/evals/my_test")
    end
  end

  describe "#generate" do
    it "raises NotImplementedError" do
      stub_const("UnimplementedEval", Class.new(described_class))
      instance = UnimplementedEval.new(eval_root: "/tmp")

      expect { instance.generate({}) }.to raise_error(NotImplementedError, "UnimplementedEval must implement #generate")
    end
  end

  describe "#initialize" do
    it "defaults eval_root to EvalEngine.configuration.eval_root" do
      stub_const("ConfigDefaultEval", Class.new(described_class))

      original = EvalEngine.configuration.eval_root
      EvalEngine.configuration.eval_root = "/from/config"

      instance = ConfigDefaultEval.new
      expect(instance.eval_dir).to eq("/from/config/config_default")
    ensure
      EvalEngine.configuration.eval_root = original
    end

    it "lets an explicit eval_root override the configured default" do
      stub_const("OverrideEval", Class.new(described_class))

      original = EvalEngine.configuration.eval_root
      EvalEngine.configuration.eval_root = "/from/config"

      instance = OverrideEval.new(eval_root: "/explicit")
      expect(instance.eval_dir).to eq("/explicit/override")
    ensure
      EvalEngine.configuration.eval_root = original
    end
  end
end
