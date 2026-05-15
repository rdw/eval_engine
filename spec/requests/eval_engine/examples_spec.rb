require "rails_helper"

RSpec.describe "EvalEngine::Examples", type: :request do
  describe "GET /:name/examples/:key" do
    it "renders breadcrumbs, the input, and the expected for an example with no runs yet" do
      get "/eval_engine/is_ebike_manufacturer/examples/amazon"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("amazon")
      expect(response.body).to include("https://amazon.com/")
      expect(response.body).to include("retailer")
      expect(response.body).to include("No runs yet for this example.")
    end

    it "renders the latest output and a red-tinted diff row for a low score" do
      run =
        EvalEngine::Run.create!(
          eval_name: "is_ebike_manufacturer",
          status: :completed,
          started_at: 1.minute.ago,
          finished_at: Time.current
        )
      EvalEngine::RunExample.create!(
        run: run,
        example_key: "amazon",
        status: :completed,
        output: "manufacturer",
        expected: "retailer",
        score: 0.25,
        score_tree: {
          "score" => 0.25
        },
        finished_at: Time.current,
        started_at: 1.second.ago
      )

      get "/eval_engine/is_ebike_manufacturer/examples/amazon"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("manufacturer")
      expect(response.body).to include("hsl(0.0, 70%, 92%)")
    end

    it "renders a green-tinted diff row for a perfect score" do
      run =
        EvalEngine::Run.create!(
          eval_name: "is_ebike_manufacturer",
          status: :completed,
          started_at: 1.minute.ago,
          finished_at: Time.current
        )
      EvalEngine::RunExample.create!(
        run: run,
        example_key: "amazon",
        status: :completed,
        output: "retailer",
        expected: "retailer",
        score: 1.0,
        score_tree: {
          "score" => 1.0
        },
        finished_at: Time.current,
        started_at: 1.second.ago
      )

      get "/eval_engine/is_ebike_manufacturer/examples/amazon"

      expect(response.body).to include("hsl(120.0, 70%, 92%)")
    end

    it "renders the error block instead of a diff for an errored run" do
      run =
        EvalEngine::Run.create!(
          eval_name: "is_ebike_manufacturer",
          status: :completed,
          started_at: 1.minute.ago,
          finished_at: Time.current
        )
      EvalEngine::RunExample.create!(
        run: run,
        example_key: "amazon",
        status: :errored,
        score: 0.0,
        error: "RuntimeError: kaboom",
        finished_at: Time.current,
        started_at: 1.second.ago
      )

      get "/eval_engine/is_ebike_manufacturer/examples/amazon"

      expect(response.body).to include("Latest run errored")
      expect(response.body).to include("RuntimeError: kaboom")
      expect(response.body).not_to include("ee-diff")
    end

    it "404s when the eval doesn't exist" do
      get "/eval_engine/does_not_exist/examples/amazon"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("does_not_exist")
    end

    it "404s when the example key isn't on disk" do
      get "/eval_engine/is_ebike_manufacturer/examples/no_such_key"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("no_such_key")
    end
  end
end
