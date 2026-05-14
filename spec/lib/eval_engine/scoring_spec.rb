require "rails_helper"

RSpec.describe EvalEngine::Scoring do
  let(:tmp_dir) { Dir.mktmpdir("scoring_spec") }
  let(:eval_name) { "color_pick" }
  let(:examples_dir) { File.join(tmp_dir, eval_name, "examples") }

  before do
    FileUtils.mkdir_p(examples_dir)
    %w[red blue green].each do |key|
      File.write(File.join(examples_dir, "#{key}.yaml"), YAML.dump("input" => { "k" => key }, "expected" => key))
    end
    @original_eval_root = EvalEngine.configuration.eval_root
    EvalEngine.configuration.eval_root = tmp_dir
  end

  after do
    FileUtils.rm_rf(tmp_dir)
    EvalEngine.configuration.eval_root = @original_eval_root
  end

  def create_example_row(eval_name:, example_key:, score:, finished_at: Time.current, run: nil)
    run ||=
      EvalEngine::Run.create!(
        eval_name: eval_name,
        status: :completed,
        started_at: 1.minute.ago,
        finished_at: finished_at
      )
    EvalEngine::RunExample.create!(
      run: run,
      example_key: example_key,
      status: :completed,
      score: score,
      finished_at: finished_at
    )
  end

  describe ".latest" do
    it "averages the most recent score per on-disk example" do
      create_example_row(eval_name: eval_name, example_key: "red", score: 0.5, finished_at: 2.hours.ago)
      create_example_row(eval_name: eval_name, example_key: "red", score: 1.0, finished_at: 1.hour.ago)
      create_example_row(eval_name: eval_name, example_key: "blue", score: 0.25)
      create_example_row(eval_name: eval_name, example_key: "green", score: 0.75)

      result = described_class.latest(eval_name)

      expect(result.mean).to eq((1.0 + 0.25 + 0.75) / 3.0)
      expect(result.per_example.map(&:example_key)).to eq(%w[blue green red])
      expect(result.per_example.map(&:score)).to eq([0.25, 0.75, 1.0])
      expect(result.missing_keys).to be_empty
    end

    it "lists keys with no run results as missing and excludes them from the mean" do
      create_example_row(eval_name: eval_name, example_key: "red", score: 1.0)

      result = described_class.latest(eval_name)

      expect(result.mean).to eq(1.0)
      expect(result.missing_keys).to contain_exactly("blue", "green")
    end

    it "ignores rows from other evals" do
      create_example_row(eval_name: "other_eval", example_key: "red", score: 0.0)
      create_example_row(eval_name: eval_name, example_key: "red", score: 1.0)

      result = described_class.latest(eval_name)

      expect(result.mean).to eq(1.0)
    end

    it "ignores rows whose example_key is no longer on disk" do
      create_example_row(eval_name: eval_name, example_key: "deleted_key", score: 0.0)
      create_example_row(eval_name: eval_name, example_key: "red", score: 1.0)

      result = described_class.latest(eval_name)

      expect(result.per_example.map(&:example_key)).to eq(%w[red])
      expect(result.missing_keys).to contain_exactly("blue", "green")
    end

    it "returns nil mean when no on-disk examples have results" do
      result = described_class.latest(eval_name)

      expect(result.mean).to be_nil
      expect(result.missing_keys).to contain_exactly("red", "blue", "green")
    end
  end

  describe ".at_checkpoint" do
    let(:checkpoint_time) { 1.day.ago }

    before { EvalEngine::Checkpoint.create!(eval_name: eval_name, checkpointed_at: checkpoint_time) }

    it "considers only rows finished strictly before the checkpoint" do
      create_example_row(eval_name: eval_name, example_key: "red", score: 0.5, finished_at: 2.days.ago)
      create_example_row(eval_name: eval_name, example_key: "red", score: 1.0, finished_at: 1.hour.ago)
      create_example_row(eval_name: eval_name, example_key: "blue", score: 1.0, finished_at: 2.days.ago)

      result = described_class.at_checkpoint(eval_name)

      expect(result.mean).to eq(0.75) # red=0.5, blue=1.0 (both before checkpoint)
      expect(result.missing_keys).to contain_exactly("green")
    end

    it "returns nil when no checkpoint is set" do
      EvalEngine::Checkpoint.find_by(eval_name: eval_name).destroy

      expect(described_class.at_checkpoint(eval_name)).to be_nil
    end

    it "returns nil mean and full missing list when no rows exist before the checkpoint" do
      create_example_row(eval_name: eval_name, example_key: "red", score: 1.0, finished_at: 1.hour.ago)

      result = described_class.at_checkpoint(eval_name)

      expect(result.mean).to be_nil
      expect(result.missing_keys).to contain_exactly("red", "blue", "green")
    end
  end
end
