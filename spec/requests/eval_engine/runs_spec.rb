require "rails_helper"

RSpec.describe "EvalEngine::Runs", type: :request do
  describe "POST /:name/runs" do
    include ActiveJob::TestHelper

    it "creates the Run row synchronously, enqueues a RunJob, and redirects" do
      expect {
        post "/eval_engine/is_ebike_manufacturer/runs", params: { only: "amazon" }
      }.to change(EvalEngine::Run, :count).by(1).and have_enqueued_job(EvalEngine::RunJob)

      run = EvalEngine::Run.order(:id).last
      expect(run.status).to eq("running")
      expect(run.run_examples).to be_empty
      expect(response).to redirect_to("/eval_engine/is_ebike_manufacturer")
      follow_redirect!
      expect(response.body).to include("Started run of is_ebike_manufacturer")
    end

    it "passes the only param to the job so it scopes execution" do
      post "/eval_engine/is_ebike_manufacturer/runs", params: { only: "amazon" }

      run = EvalEngine::Run.order(:id).last
      expect(EvalEngine::RunJob).to have_been_enqueued.with(run.id, only: ["amazon"])
    end

    it "redirects to root with an alert when the eval doesn't exist" do
      post "/eval_engine/does_not_exist/runs"

      expect(response).to redirect_to("/eval_engine/")
      follow_redirect!
      expect(response.body).to include("Eval not found")
    end
  end

  describe "DELETE /:name/runs/:id" do
    it "destroys the run and redirects" do
      run =
        EvalEngine::Run.create!(
          eval_name: "is_ebike_manufacturer",
          status: :completed,
          started_at: 1.minute.ago,
          finished_at: Time.current
        )

      expect { delete "/eval_engine/is_ebike_manufacturer/runs/#{run.id}" }.to change(EvalEngine::Run, :count).by(-1)

      expect(response).to redirect_to("/eval_engine/is_ebike_manufacturer")
    end

    it "404s when the run isn't found under that eval_name" do
      other_run = EvalEngine::Run.create!(eval_name: "other_eval", status: :completed, started_at: 1.minute.ago)

      expect { delete "/eval_engine/is_ebike_manufacturer/runs/#{other_run.id}" }.not_to change(EvalEngine::Run, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
