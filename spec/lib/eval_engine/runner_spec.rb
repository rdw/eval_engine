require "rails_helper"

RSpec.describe EvalEngine::Runner do
  let(:tmp_dir) { Dir.mktmpdir("runner_spec") }
  let(:eval_name) { "color_pick" }
  let(:examples_dir) { File.join(tmp_dir, eval_name, "examples") }

  before { FileUtils.mkdir_p(examples_dir) }
  after { FileUtils.rm_rf(tmp_dir) }

  def write_example(key, input:, expected:)
    File.write(File.join(examples_dir, "#{key}.yaml"), YAML.dump("input" => input, "expected" => expected))
  end

  describe "happy path" do
    let(:eval_class) do
      Class.new(EvalEngine::Eval) do
        output_type :string, match: :exact

        define_method(:generate) { |input| input["color"] }
      end
    end

    before do
      stub_const("ColorPickEval", eval_class)
      write_example("red", input: { "color" => "red" }, expected: "red")
      write_example("blue", input: { "color" => "blue" }, expected: "blue")
    end

    it "creates a Run row that transitions running → completed" do
      run = described_class.new(eval_class: eval_class, eval_root: tmp_dir, parallelism: 1).run!

      expect(run).to have_attributes(eval_name: "color_pick", status: "completed", example_count: 2)
      expect(run.started_at).to be_present
      expect(run.finished_at).to be_present
    end

    it "creates one RunExample per example with snapshotted input/expected/output and score tree" do
      run = described_class.new(eval_class: eval_class, eval_root: tmp_dir, parallelism: 1).run!

      red = run.run_examples.find_by(example_key: "red")
      expect(red).to have_attributes(
        status: "completed",
        input: {
          "color" => "red"
        },
        expected: "red",
        output: "red",
        score: 1.0,
        score_tree: {
          "score" => 1.0
        }
      )
      expect(red.started_at).to be_present
      expect(red.finished_at).to be_present
    end
  end

  describe "score is preserved verbatim regardless of value" do
    let(:eval_class) do
      Class.new(EvalEngine::Eval) do
        output_type :string, match: :exact

        define_method(:generate) { |input| input["color"] }
      end
    end

    before do
      stub_const("ColorPickEval", eval_class)
      write_example("matching", input: { "color" => "red" }, expected: "red")
      write_example("mismatching", input: { "color" => "red" }, expected: "blue")
    end

    it "marks both examples completed (no pass/fail judgment) and stores their actual score" do
      run = described_class.new(eval_class: eval_class, eval_root: tmp_dir, parallelism: 1).run!

      matching = run.run_examples.find_by(example_key: "matching")
      mismatching = run.run_examples.find_by(example_key: "mismatching")

      expect(matching).to be_completed
      expect(mismatching).to be_completed
      expect(matching.score).to eq(1.0)
      expect(mismatching.score).to eq(0.25)
    end
  end

  describe "generate raises an exception" do
    let(:eval_class) do
      Class.new(EvalEngine::Eval) do
        output_type :string, match: :exact

        define_method(:generate) do |input|
          raise "boom" if input["color"] == "red"

          input["color"]
        end
      end
    end

    before do
      stub_const("ColorPickEval", eval_class)
      write_example("red", input: { "color" => "red" }, expected: "red")
      write_example("blue", input: { "color" => "blue" }, expected: "blue")
    end

    it "records the exception on the example row but continues the run" do
      run = described_class.new(eval_class: eval_class, eval_root: tmp_dir, parallelism: 1).run!

      red = run.run_examples.find_by(example_key: "red")
      blue = run.run_examples.find_by(example_key: "blue")

      expect(run).to be_completed
      expect(red).to have_attributes(status: "errored", score: 0.0, output: nil, score_tree: nil)
      expect(red.error).to include("RuntimeError", "boom")
      expect(blue).to be_completed
    end
  end

  describe "generate returns a value that fails output_type validation" do
    let(:eval_class) do
      Class.new(EvalEngine::Eval) do
        output_type :string, match: :exact

        define_method(:generate) { |_input| 42 }
      end
    end

    before do
      stub_const("ColorPickEval", eval_class)
      write_example("x", input: { "color" => "red" }, expected: "red")
    end

    it "marks the example as errored with a validation message" do
      run = described_class.new(eval_class: eval_class, eval_root: tmp_dir, parallelism: 1).run!

      example = run.run_examples.first
      expect(example).to be_errored
      expect(example.error).to include("Expected string, got Integer")
    end
  end

  describe "example validation runs before the run starts" do
    let(:eval_class) do
      Class.new(EvalEngine::Eval) do
        input_type :hash do
          field :color, :string
        end
        output_type :string, match: :exact

        define_method(:generate) { |input| input["color"] }
      end
    end

    before do
      stub_const("ColorPickEval", eval_class)
      write_example("bad_input", input: { "wrong_field" => "red" }, expected: "red")
      write_example("good_input", input: { "color" => "blue" }, expected: "blue")
    end

    it "raises ExamplesInvalid with all per-example failures and creates no Run" do
      runner = described_class.new(eval_class: eval_class, eval_root: tmp_dir, parallelism: 1)

      expect { runner.run! }.to raise_error(EvalEngine::Runner::ExamplesInvalid) do |err|
        expect(err.failures.length).to eq(1)
        expect(err.failures.first[:label]).to include("bad_input")
        expect(err.failures.first[:message]).to include("color: Missing required field")
      end

      expect(EvalEngine::Run.count).to eq(0)
    end
  end

  describe "only: filters which examples run" do
    let(:eval_class) do
      Class.new(EvalEngine::Eval) do
        output_type :string, match: :exact

        define_method(:generate) { |input| input["color"] }
      end
    end

    before do
      stub_const("ColorPickEval", eval_class)
      write_example("red", input: { "color" => "red" }, expected: "red")
      write_example("blue", input: { "color" => "blue" }, expected: "blue")
      write_example("green", input: { "color" => "green" }, expected: "green")
    end

    it "runs only the requested examples and counts them in the Run row" do
      run = described_class.new(eval_class: eval_class, eval_root: tmp_dir, only: %w[red blue], parallelism: 1).run!

      expect(run.example_count).to eq(2)
      expect(run.run_examples.pluck(:example_key)).to contain_exactly("red", "blue")
    end
  end

  describe "missing output_type" do
    let(:eval_class) { Class.new(EvalEngine::Eval) { define_method(:generate) { |_input| "anything" } } }

    before do
      stub_const("ColorPickEval", eval_class)
      write_example("any", input: { "color" => "red" }, expected: "red")
    end

    it "fails fast with a clear error before any DB rows are created" do
      runner = described_class.new(eval_class: eval_class, eval_root: tmp_dir, parallelism: 1)

      expect { runner.run! }.to raise_error(ArgumentError, /must declare an output_type/)
      expect(EvalEngine::Run.count).to eq(0)
    end
  end

  describe "block callback for per-example progress" do
    let(:eval_class) do
      Class.new(EvalEngine::Eval) do
        output_type :string, match: :exact
        define_method(:generate) { |input| input["color"] }
      end
    end

    before do
      stub_const("ColorPickEval", eval_class)
      write_example("red", input: { "color" => "red" }, expected: "red")
      write_example("blue", input: { "color" => "blue" }, expected: "wrong")
    end

    it "invokes the block once per example with the saved RunExample row" do
      yielded = []
      described_class
        .new(eval_class: eval_class, eval_root: tmp_dir, parallelism: 1)
        .run! { |row| yielded << [row.example_key, row.score] }

      expect(yielded).to contain_exactly(["red", 1.0], ["blue", 0.25])
    end

    it "yields errored example rows too" do
      eval_class_that_raises =
        Class.new(EvalEngine::Eval) do
          output_type :string, match: :exact
          define_method(:generate) { |_input| raise "boom" }
        end
      stub_const("ColorPickEval", eval_class_that_raises)

      yielded = []
      described_class
        .new(eval_class: eval_class_that_raises, eval_root: tmp_dir, parallelism: 1)
        .run! { |row| yielded << row }

      expect(yielded.map(&:example_key)).to contain_exactly("red", "blue")
      expect(yielded).to all(be_errored)
    end
  end

  describe "EvalEngine.run convenience" do
    before do
      eval_dir = File.join(tmp_dir, eval_name)
      File.write(File.join(eval_dir, "#{eval_name}_eval.rb"), <<~RUBY)
        class ColorPickEval < EvalEngine::Eval
          output_type :string, match: :exact

          def generate(input)
            input["color"]
          end
        end
      RUBY

      write_example("red", input: { "color" => "red" }, expected: "red")
    end

    it "loads the eval from disk and runs it end-to-end" do
      run = EvalEngine.run(eval_name, eval_root: tmp_dir, parallelism: 1)

      expect(run).to be_completed
      expect(run.run_examples.first).to be_completed
    end
  end
end
