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

  describe "show" do
    let!(:run) do
      EvalEngine::Run.create!(
        eval_name: "is_ebike_manufacturer",
        status: :completed,
        started_at: 1.minute.ago,
        finished_at: Time.current
      )
    end

    before do
      %w[amazon blixbike heybike].each do |key|
        EvalEngine::RunExample.create!(
          run: run,
          example_key: key,
          status: :completed,
          score: 1.0,
          finished_at: Time.current
        )
      end
    end

    it "shows the latest mean and per-example breakdown" do
      stdout, _ = run_cli(%w[show is_ebike_manufacturer])

      expect(stdout).to include("is_ebike_manufacturer")
      expect(stdout).to match(%r{Latest:\s+1\.000\s+\(3/4 examples\)})
      expect(stdout).to include("amazon", "blixbike", "heybike")
    end

    it "flags on-disk examples that have never been run" do
      stdout, _ = run_cli(%w[show is_ebike_manufacturer])

      expect(stdout).to include("lectricebikes", "(not yet run)")
    end

    it "renders 'no checkpoint set' when one isn't promoted yet" do
      stdout, _ = run_cli(%w[show is_ebike_manufacturer])

      expect(stdout).to match(/Checkpoint:\s+\(no checkpoint set\)/)
    end

    it "shows a checkpoint score and snapshot timestamp once promoted" do
      EvalEngine::Checkpoint.create!(eval_name: "is_ebike_manufacturer", checkpointed_at: 1.day.from_now)

      stdout, _ = run_cli(%w[show is_ebike_manufacturer])

      expect(stdout).to match(%r{Checkpoint:\s+1\.000\s+\(3/4 examples\) snapshot @ })
    end
  end

  describe "debug" do
    let!(:run) do
      EvalEngine::Run.create!(
        eval_name: "is_ebike_manufacturer",
        status: :completed,
        started_at: 1.minute.ago,
        finished_at: Time.current
      )
    end

    before do
      EvalEngine::RunExample.create!(
        run: run,
        example_key: "blixbike",
        status: :completed,
        input: {
          "url" => "https://blixbike.com/"
        },
        expected: "manufacturer",
        output: "manufacturer",
        score: 1.0,
        score_tree: {
          "score" => 1.0
        },
        finished_at: Time.current
      )
    end

    it "prints input/expected/output/score_tree for each example by default" do
      stdout, _ = run_cli(%w[debug is_ebike_manufacturer])

      expect(stdout).to include("blixbike", "1.000", "input:", "expected:", "output:", "score_tree:")
      expect(stdout).to include("https://blixbike.com/")
    end

    it "filters to only the requested keys with --only" do
      EvalEngine::RunExample.create!(
        run: run,
        example_key: "amazon",
        status: :completed,
        input: {
          "url" => "https://amazon.com/"
        },
        expected: "retailer",
        output: "retailer",
        score: 1.0,
        score_tree: {
          "score" => 1.0
        },
        finished_at: Time.current
      )

      stdout, _ = run_cli(%w[debug is_ebike_manufacturer --only blixbike])

      expect(stdout).to include("blixbike")
      expect(stdout).not_to include("amazon")
    end

    it "prints the full error for errored rows instead of the diff fields" do
      EvalEngine::RunExample.create!(
        run: run,
        example_key: "lectricebikes",
        status: :errored,
        score: 0.0,
        error: "RuntimeError: boom\n  /app/foo.rb:1",
        finished_at: Time.current
      )

      stdout, _ = run_cli(%w[debug is_ebike_manufacturer --only lectricebikes])

      expect(stdout).to include("lectricebikes", "ERROR", "RuntimeError: boom", "/app/foo.rb:1")
    end
  end

  describe "rescore" do
    after { Object.send(:remove_const, :IsEbikeManufacturerEval) if Object.const_defined?(:IsEbikeManufacturerEval) }

    let!(:run) do
      EvalEngine::Run.create!(
        eval_name: "is_ebike_manufacturer",
        status: :completed,
        started_at: 1.minute.ago,
        finished_at: Time.current
      )
    end

    before do
      # Stale row: expected was "marketplace" at run time, but on disk it's "manufacturer".
      EvalEngine::RunExample.create!(
        run: run,
        example_key: "blixbike",
        status: :completed,
        input: {
          "url" => "https://blixbike.com/"
        },
        expected: "marketplace",
        output: "manufacturer",
        score: 0.25,
        score_tree: {
          "score" => 0.25
        },
        finished_at: Time.current
      )
    end

    it "recomputes the score against the on-disk expected" do
      run_cli(%w[rescore is_ebike_manufacturer])

      row = EvalEngine::RunExample.find_by(example_key: "blixbike")
      expect(row.expected).to eq("manufacturer")
      expect(row.score).to eq(1.0)
    end

    it "prints a summary with the rescored count" do
      stdout, _ = run_cli(%w[rescore is_ebike_manufacturer])

      expect(stdout).to include("Rescoring is_ebike_manufacturer", "Rescored 1 run examples")
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
