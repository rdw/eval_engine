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

    describe "examples table sorting" do
      def example_keys_in_order(body)
        body.scan(%r{href="/eval_engine/is_ebike_manufacturer/examples/([^"]+)"}).flatten
      end

      it "defaults to sorting by key ascending" do
        get "/eval_engine/is_ebike_manufacturer"

        expect(example_keys_in_order(response.body)).to eq(%w[amazon blixbike heybike lectricebikes])
      end

      it "reverses the order when ?sort=key&dir=desc" do
        get "/eval_engine/is_ebike_manufacturer", params: { sort: "key", dir: "desc" }

        expect(example_keys_in_order(response.body)).to eq(%w[lectricebikes heybike blixbike amazon])
      end

      it "sorts by score descending and pushes nil-score rows to the end" do
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
          score: 0.25,
          finished_at: Time.current
        )
        EvalEngine::RunExample.create!(
          run: run,
          example_key: "blixbike",
          status: :completed,
          score: 1.0,
          finished_at: Time.current
        )

        get "/eval_engine/is_ebike_manufacturer", params: { sort: "score", dir: "desc" }

        keys = example_keys_in_order(response.body)
        expect(keys.first(2)).to eq(%w[blixbike amazon])
        expect(keys.last(2)).to contain_exactly("heybike", "lectricebikes")
      end

      it "falls back to key when given an unknown sort column" do
        get "/eval_engine/is_ebike_manufacturer", params: { sort: "garbage" }

        expect(example_keys_in_order(response.body)).to eq(%w[amazon blixbike heybike lectricebikes])
      end

      it "links each header to the next sort direction" do
        get "/eval_engine/is_ebike_manufacturer", params: { sort: "score", dir: "asc" }

        expect(response.body).to include('href="/eval_engine/is_ebike_manufacturer?dir=desc&amp;sort=score"')
        expect(response.body).to include('href="/eval_engine/is_ebike_manufacturer?dir=asc&amp;sort=key"')
      end
    end
  end

  describe "POST /:name/rescore" do
    it "redirects with a notice describing how many rows were rescored" do
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
        output: true,
        score: 0.0,
        finished_at: Time.current
      )

      post "/eval_engine/is_ebike_manufacturer/rescore"

      expect(response).to redirect_to("/eval_engine/is_ebike_manufacturer")
      follow_redirect!
      expect(response.body).to include("Rescored 1 rows")
    end

    it "redirects to root with an alert when the eval doesn't exist" do
      post "/eval_engine/does_not_exist/rescore"

      expect(response).to redirect_to("/eval_engine/")
      follow_redirect!
      expect(response.body).to include("Eval not found")
    end
  end
end
