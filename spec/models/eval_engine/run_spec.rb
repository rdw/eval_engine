require "rails_helper"

RSpec.describe EvalEngine::Run, type: :model do
  let(:run) do
    described_class.create!(
      eval_name: "is_ebike_manufacturer",
      status: :running,
      started_at: Time.current,
      example_count: 4
    )
  end

  describe "persistence" do
    it "saves the declared attributes" do
      expect(run).to have_attributes(eval_name: "is_ebike_manufacturer", status: "running", example_count: 4)
      expect(run).to be_persisted
    end
  end

  describe "status enum" do
    it "exposes predicate methods for each declared state" do
      expect(run).to be_running
      run.update!(status: :completed, finished_at: Time.current)
      expect(run).to be_completed
      run.update!(status: :failed)
      expect(run).to be_failed
    end

    it "exposes a class-level scope per status" do
      run
      expect(described_class.running).to contain_exactly(run)
      expect(described_class.completed).to be_empty
    end

    it "rejects invalid status values" do
      expect { run.update!(status: :bogus) }.to raise_error(ArgumentError)
    end
  end

  describe "association with run_examples" do
    let!(:run_example) do
      EvalEngine::RunExample.create!(run: run, example_key: "blixbike", status: :completed, score: 1.0)
    end

    it "exposes its run_examples" do
      expect(run.run_examples).to contain_exactly(run_example)
    end

    it "destroys dependent run_examples when the run is destroyed" do
      expect { run.destroy! }.to change(EvalEngine::RunExample, :count).by(-1)
    end
  end
end
