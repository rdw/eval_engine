require "rails_helper"

RSpec.describe "EvalEngine::Runs", type: :request do
  describe "POST /:name/runs" do
    it "runs the eval and creates a Run row, redirecting back to the eval page" do
      expect { post "/eval_engine/is_ebike_manufacturer/runs", params: { only: "amazon" } }.to change(
        EvalEngine::Run,
        :count
      ).by(1)

      expect(response).to redirect_to("/eval_engine/is_ebike_manufacturer")
      follow_redirect!
      expect(response.body).to include("Ran is_ebike_manufacturer")
    end

    it "passes the only param down so a single example is run" do
      post "/eval_engine/is_ebike_manufacturer/runs", params: { only: "amazon" }

      run = EvalEngine::Run.order(:id).last
      expect(run.run_examples.pluck(:example_key)).to eq(["amazon"])
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
