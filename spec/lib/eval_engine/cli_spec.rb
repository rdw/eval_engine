require "rails_helper"
require "eval_engine/cli"

RSpec.describe EvalEngine::CLI do
  def run_cli(argv)
    captured_stdout = StringIO.new
    captured_stderr = StringIO.new
    real_stdout, real_stderr = $stdout, $stderr
    $stdout, $stderr = captured_stdout, captured_stderr
    described_class.start(argv)
    [captured_stdout.string, captured_stderr.string]
  ensure
    $stdout, $stderr = real_stdout, real_stderr
  end

  describe "list" do
    it "prints each discovered eval name" do
      stdout, _ = run_cli(["list"])
      expect(stdout).to include("is_ebike_manufacturer")
    end
  end

  describe "run" do
    after { Object.send(:remove_const, :IsEbikeManufacturerEval) if Object.const_defined?(:IsEbikeManufacturerEval) }

    it "prints a per-example status line as each example finishes" do
      stdout, _ = run_cli(%w[run is_ebike_manufacturer])

      %w[amazon blixbike heybike lectricebikes].each { |key| expect(stdout).to match(/^\s+#{key}\s+1\.000$/) }
    end

    it "prints a header before the first example and a summary at the end" do
      stdout, _ = run_cli(%w[run is_ebike_manufacturer])

      created_run = EvalEngine::Run.last
      expect(created_run).to have_attributes(eval_name: "is_ebike_manufacturer", status: "completed")

      expect(stdout).to include("Running is_ebike_manufacturer")
      expect(stdout).to match(/Run ##{created_run.id} completed in \d+\.\d+s \(4 examples\)\./)
      expect(stdout).to include("Mean score: 1.000")
    end

    it "honors --only by limiting examples to the listed keys" do
      run_cli(%w[run is_ebike_manufacturer --only blixbike heybike])

      run = EvalEngine::Run.last
      expect(run.example_count).to eq(2)
      expect(run.run_examples.pluck(:example_key)).to contain_exactly("blixbike", "heybike")
    end

    it "exits non-zero with a clear message if the eval doesn't exist" do
      expect { run_cli(%w[run nonexistent_eval]) }.to raise_error(SystemExit) do |err|
        expect(err.status).to eq(1)
      end
    end
  end

  describe "promote" do
    it "creates a checkpoint for the eval defaulting to now" do
      before_call = Time.current
      run_cli(%w[promote is_ebike_manufacturer])

      checkpoint = EvalEngine::Checkpoint.find_by(eval_name: "is_ebike_manufacturer")
      expect(checkpoint.checkpointed_at).to be_between(before_call, Time.current).inclusive
    end

    it "uses --at when provided" do
      run_cli(%w[promote is_ebike_manufacturer --at 2025-01-15T12:00:00Z])

      checkpoint = EvalEngine::Checkpoint.find_by(eval_name: "is_ebike_manufacturer")
      expect(checkpoint.checkpointed_at).to eq(Time.utc(2025, 1, 15, 12, 0, 0))
    end

    it "updates the existing checkpoint instead of duplicating (one per eval)" do
      run_cli(%w[promote is_ebike_manufacturer --at 2025-01-15T12:00:00Z])
      run_cli(%w[promote is_ebike_manufacturer --at 2025-02-15T12:00:00Z])

      checkpoints = EvalEngine::Checkpoint.where(eval_name: "is_ebike_manufacturer")
      expect(checkpoints.count).to eq(1)
      expect(checkpoints.first.checkpointed_at).to eq(Time.utc(2025, 2, 15, 12, 0, 0))
    end
  end
end
