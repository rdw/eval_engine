require "rails_helper"

RSpec.describe "EvalEngine::Checkpoints", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  describe "POST /:name/checkpoint" do
    it "creates a checkpoint at Time.current when no run_id is given" do
      freeze_at = Time.current.change(usec: 0)
      travel_to(freeze_at) { post "/eval_engine/is_ebike_manufacturer/checkpoint" }

      checkpoint = EvalEngine::Checkpoint.find_by(eval_name: "is_ebike_manufacturer")
      expect(checkpoint).not_to be_nil
      expect(checkpoint.checkpointed_at.to_i).to eq(freeze_at.to_i)
      expect(response).to redirect_to("/eval_engine/is_ebike_manufacturer")
    end

    it "uses the given run's finished_at when run_id is provided" do
      finished = 5.minutes.ago.change(usec: 0)
      run =
        EvalEngine::Run.create!(
          eval_name: "is_ebike_manufacturer",
          status: :completed,
          started_at: 10.minutes.ago,
          finished_at: finished
        )

      post "/eval_engine/is_ebike_manufacturer/checkpoint", params: { run_id: run.id }

      checkpoint = EvalEngine::Checkpoint.find_by(eval_name: "is_ebike_manufacturer")
      expect(checkpoint.checkpointed_at.to_i).to eq(finished.to_i)
    end

    it "updates the existing checkpoint instead of erroring on the uniqueness constraint" do
      EvalEngine::Checkpoint.create!(eval_name: "is_ebike_manufacturer", checkpointed_at: 1.day.ago)

      expect { post "/eval_engine/is_ebike_manufacturer/checkpoint" }.not_to change(EvalEngine::Checkpoint, :count)

      expect(response).to redirect_to("/eval_engine/is_ebike_manufacturer")
    end
  end
end
