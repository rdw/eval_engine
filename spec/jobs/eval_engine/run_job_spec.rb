require "rails_helper"

RSpec.describe EvalEngine::RunJob, type: :job do
  describe "#perform" do
    it "executes the existing :running Run and transitions it to :completed" do
      run = build_running_run(eval_name: "is_ebike_manufacturer")

      described_class.perform_now(run.id, only: ["amazon"])

      expect(run.reload.status).to eq("completed")
      expect(run.run_examples.pluck(:example_key)).to eq(["amazon"])
    end

    it "no-ops when the Run is no longer :running (e.g. deleted)" do
      expect { described_class.perform_now(999_999, only: nil) }.not_to raise_error
    end

    it "no-ops when the Run has already transitioned out of :running" do
      run =
        EvalEngine::Run.create!(
          eval_name: "is_ebike_manufacturer",
          status: :completed,
          started_at: 1.minute.ago,
          finished_at: Time.current,
          example_count: 0
        )

      expect { described_class.perform_now(run.id, only: nil) }.not_to change(EvalEngine::RunExample, :count)
    end

    it "broadcasts a Turbo stream replace per finished example targeting that example's row" do
      run = build_running_run(eval_name: "is_ebike_manufacturer")

      expect {
        described_class.perform_now(run.id, only: ["amazon"])
      }.to have_broadcasted_to("is_ebike_manufacturer:examples")
        .from_channel(Turbo::StreamsChannel)
        .with { |payload|
          expect(payload).to include('action="replace"')
          expect(payload).to include('target="eval_engine_example_row_amazon"')
        }
    end

    it "broadcasts a Turbo stream replace when the Run transitions to :completed targeting that run's row" do
      run = build_running_run(eval_name: "is_ebike_manufacturer")

      expect {
        described_class.perform_now(run.id, only: ["amazon"])
      }.to have_broadcasted_to("is_ebike_manufacturer:runs")
        .from_channel(Turbo::StreamsChannel)
        .with { |payload|
          expect(payload).to include('action="replace"')
          expect(payload).to include(%(target="run_#{run.id}"))
        }
    end

    it "marks the Run :failed and re-raises when the eval is no longer loadable" do
      run = build_running_run(eval_name: "is_ebike_manufacturer")
      allow(EvalEngine::Loader).to receive(:load_eval).and_raise(EvalEngine::Loader::NotFoundError, "gone")

      expect { described_class.perform_now(run.id, only: nil) }.to raise_error(EvalEngine::Loader::NotFoundError)
      expect(run.reload.status).to eq("failed")
      expect(run.finished_at).to be_present
    end
  end

  def build_running_run(eval_name:)
    eval_class = EvalEngine::Loader.load_eval(eval_name)
    EvalEngine::Runner.new(eval_class: eval_class, only: ["amazon"]).start!
  end
end
