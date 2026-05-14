require "rails_helper"

RSpec.describe EvalEngine::Loader do
  let(:tmp_dir) { Dir.mktmpdir("loader_spec") }

  after do
    FileUtils.rm_rf(tmp_dir)
    Object.send(:remove_const, :ColorPickEval) if Object.const_defined?(:ColorPickEval)
  end

  describe ".load_eval" do
    let(:eval_dir) { File.join(tmp_dir, "color_pick") }
    let(:eval_file) { File.join(eval_dir, "color_pick_eval.rb") }

    before do
      FileUtils.mkdir_p(eval_dir)
      File.write(eval_file, <<~RUBY)
        class ColorPickEval < EvalEngine::Eval
          output_type :string, match: :exact

          def generate(input)
            input["color"]
          end
        end
      RUBY
    end

    it "loads the file and returns the class" do
      klass = described_class.load_eval("color_pick", eval_root: tmp_dir)

      expect(klass.name).to eq("ColorPickEval")
      expect(klass.eval_name).to eq("color_pick")
    end

    it "raises NotFoundError when the eval does not exist" do
      expect { described_class.load_eval("nope", eval_root: tmp_dir) }.to raise_error(
        EvalEngine::Loader::NotFoundError,
        /nope/
      )
    end

    it "uses EvalEngine.configuration.eval_root by default" do
      original = EvalEngine.configuration.eval_root
      EvalEngine.configuration.eval_root = tmp_dir

      klass = described_class.load_eval("color_pick")
      expect(klass.name).to eq("ColorPickEval")
    ensure
      EvalEngine.configuration.eval_root = original
    end
  end

  describe ".discover" do
    before do
      %w[alpha beta gamma].each do |name|
        dir = File.join(tmp_dir, name)
        FileUtils.mkdir_p(dir)
        File.write(File.join(dir, "#{name}_eval.rb"), "")
      end

      FileUtils.mkdir_p(File.join(tmp_dir, "no_eval_here"))
    end

    it "returns each eval name found under the root, sorted" do
      expect(described_class.discover(eval_root: tmp_dir)).to eq(%w[alpha beta gamma])
    end

    it "ignores subdirectories without a matching <name>_eval.rb file" do
      expect(described_class.discover(eval_root: tmp_dir)).not_to include("no_eval_here")
    end

    it "returns an empty array when the root has no evals" do
      empty_root = Dir.mktmpdir("empty_loader")
      expect(described_class.discover(eval_root: empty_root)).to eq([])
    ensure
      FileUtils.rm_rf(empty_root)
    end
  end
end
