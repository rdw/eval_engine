require "rails_helper"

RSpec.describe "EvalEngine::Evals", type: :request do
  describe "GET /" do
    it "renders an empty-state when no evals are present in the eval_root" do
      original_root = EvalEngine.configuration.eval_root
      Dir.mktmpdir("evals_index_empty") do |empty_root|
        EvalEngine.configuration.eval_root = empty_root
        get "/eval_engine/"
      ensure
        EvalEngine.configuration.eval_root = original_root
      end

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No evals found")
    end

    it "lists each discovered eval with a link to its show page" do
      get "/eval_engine/"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("is_ebike_manufacturer")
      expect(response.body).to include('href="/eval_engine/is_ebike_manufacturer"')
    end

    it "renders the eval's latest score from real RunExample rows" do
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
        score: 1.0,
        finished_at: Time.current
      )

      get "/eval_engine/"

      expect(response.body).to include("1.000")
    end
  end

  describe "GET /:name" do
    it "renders the eval's name, examples count, and runs section" do
      get "/eval_engine/is_ebike_manufacturer"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("is_ebike_manufacturer")
      expect(response.body).to include("Examples (4)")
      expect(response.body).to include("Recent runs")
      %w[amazon blixbike heybike lectricebikes].each { |key| expect(response.body).to include(key) }
    end

    it "renders 'not yet run' for examples without a result" do
      get "/eval_engine/is_ebike_manufacturer"

      expect(response.body).to include("not yet run")
    end

    it "renders the latest run's row in the recent runs table" do
      run =
        EvalEngine::Run.create!(
          eval_name: "is_ebike_manufacturer",
          status: :completed,
          started_at: 1.minute.ago,
          finished_at: Time.current,
          example_count: 4
        )
      4.times do |i|
        EvalEngine::RunExample.create!(
          run: run,
          example_key: "amazon-#{i}",
          status: :completed,
          score: 1.0,
          finished_at: Time.current
        )
      end

      get "/eval_engine/is_ebike_manufacturer"

      expect(response.body).to include("completed", "1.000")
    end

    it "404s when the eval doesn't exist" do
      get "/eval_engine/does_not_exist"

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include("does_not_exist")
    end
  end
end
