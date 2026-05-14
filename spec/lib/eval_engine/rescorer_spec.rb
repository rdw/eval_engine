require "rails_helper"

RSpec.describe EvalEngine::Rescorer do
  let(:tmp_dir) { Dir.mktmpdir("rescorer_spec") }
  let(:eval_name) { "color_pick" }
  let(:examples_dir) { File.join(tmp_dir, eval_name, "examples") }
  let(:eval_dir) { File.join(tmp_dir, eval_name) }

  before do
    FileUtils.mkdir_p(examples_dir)
    File.write(File.join(eval_dir, "#{eval_name}_eval.rb"), <<~RUBY)
      class ColorPickEval < EvalEngine::Eval
        input_type :hash do
          field :k, :string
        end
        output_type :string, match: :exact

        def generate(input)
          input["k"]
        end
      end
    RUBY

    File.write(File.join(examples_dir, "red.yaml"), YAML.dump("input" => { "k" => "red" }, "expected" => "red"))
  end

  after do
    FileUtils.rm_rf(tmp_dir)
    Object.send(:remove_const, :ColorPickEval) if Object.const_defined?(:ColorPickEval)
  end

  def make_run_example(example_key:, output:, expected:, score:, errored: false, run: nil)
    run ||=
      EvalEngine::Run.create!(
        eval_name: eval_name,
        status: :completed,
        started_at: 1.minute.ago,
        finished_at: Time.current
      )
    EvalEngine::RunExample.create!(
      run: run,
      example_key: example_key,
      status: errored ? :errored : :completed,
      score: score,
      output: errored ? nil : output,
      expected: expected,
      finished_at: Time.current,
      error: errored ? "boom" : nil
    )
  end

  it "recomputes score from current on-disk expected and updates the row" do
    # Row was scored 0.25 (string-mismatch floor) because expected on disk used to be "blue".
    # Now expected on disk is "red", and output is "red" → should rescore to 1.0.
    row = make_run_example(example_key: "red", output: "red", expected: "blue", score: 0.25)

    described_class.rescore_all(eval_name, eval_root: tmp_dir)

    row.reload
    expect(row.score).to eq(1.0)
    expect(row.expected).to eq("red")
    expect(row.score_tree).to eq("score" => 1.0)
  end

  it "skips errored rows since they have no output to match" do
    errored = make_run_example(example_key: "red", output: nil, expected: "red", score: 0.0, errored: true)

    result = described_class.rescore_all(eval_name, eval_root: tmp_dir)

    expect(result.skipped_errored).to eq(1)
    expect(result.rescored_count).to eq(0)
    expect(errored.reload.score).to eq(0.0)
  end

  it "skips rows whose example_key was deleted from disk" do
    deleted_key_row = make_run_example(example_key: "deleted_key", output: "x", expected: "x", score: 1.0)

    result = described_class.rescore_all(eval_name, eval_root: tmp_dir)

    expect(result.skipped_missing_example).to eq(1)
    expect(result.rescored_count).to eq(0)
  end

  it "touches updated_at on every Run that owns a rescored example" do
    older_time = 1.day.ago
    run =
      EvalEngine::Run.create!(
        eval_name: eval_name,
        status: :completed,
        started_at: older_time,
        finished_at: older_time,
        updated_at: older_time
      )
    make_run_example(run: run, example_key: "red", output: "red", expected: "blue", score: 0.25)

    described_class.rescore_all(eval_name, eval_root: tmp_dir)

    expect(run.reload.updated_at).to be > older_time
  end

  it "returns counts and the touched run ids" do
    run =
      EvalEngine::Run.create!(
        eval_name: eval_name,
        status: :completed,
        started_at: 1.minute.ago,
        finished_at: Time.current
      )
    make_run_example(run: run, example_key: "red", output: "red", expected: "blue", score: 0.25)
    make_run_example(run: run, example_key: "deleted_key", output: "x", expected: "x", score: 1.0)
    make_run_example(run: run, example_key: "red", output: nil, expected: "red", score: 0.0, errored: true)

    result = described_class.rescore_all(eval_name, eval_root: tmp_dir)

    expect(result.rescored_count).to eq(1)
    expect(result.skipped_errored).to eq(1)
    expect(result.skipped_missing_example).to eq(1)
    expect(result.touched_run_ids).to eq([run.id])
  end
end
