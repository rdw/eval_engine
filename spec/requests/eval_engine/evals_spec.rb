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

    it "loads Turbo JS via the engine layout" do
      get "/eval_engine/"

      expect(response.body).to match(%r{<script src="/assets/turbo-[^"]+\.js" type="module"></script>})
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

    describe "checkpoint-vs-latest delta column" do
      def seed_run(score:, at: Time.current)
        run =
          EvalEngine::Run.create!(
            eval_name: "is_ebike_manufacturer",
            status: :completed,
            started_at: at - 1.second,
            finished_at: at
          )
        EvalEngine::RunExample.create!(
          run: run,
          example_key: "amazon",
          status: :completed,
          score: score,
          finished_at: at
        )
        run
      end

      it "renders a negative delta with a red background that grows brighter with magnitude" do
        seed_run(score: 1.0, at: 10.minutes.ago)
        EvalEngine::Checkpoint.create!(eval_name: "is_ebike_manufacturer", checkpointed_at: 5.minutes.ago)
        seed_run(score: 0.25, at: 1.minute.ago)

        get "/eval_engine/"

        expect(response.body).to include("-0.75")
        expect(response.body).to match(/hsl\(0,[^"]*"/)
      end

      it "renders a positive delta with a green background that grows brighter with magnitude" do
        seed_run(score: 0.25, at: 10.minutes.ago)
        EvalEngine::Checkpoint.create!(eval_name: "is_ebike_manufacturer", checkpointed_at: 5.minutes.ago)
        seed_run(score: 1.0, at: 1.minute.ago)

        get "/eval_engine/"

        expect(response.body).to include("+0.75")
        expect(response.body).to match(/hsl\(120,[^"]*"/)
      end

      it "omits the delta entirely when the absolute difference is below 0.01" do
        seed_run(score: 1.0, at: 10.minutes.ago)
        EvalEngine::Checkpoint.create!(eval_name: "is_ebike_manufacturer", checkpointed_at: 5.minutes.ago)
        seed_run(score: 0.999, at: 1.minute.ago)

        get "/eval_engine/"

        expect(response.body).not_to include("ee-delta")
      end

      it "omits the delta when there is no checkpoint to compare against" do
        seed_run(score: 1.0)

        get "/eval_engine/"

        expect(response.body).not_to include("ee-delta")
      end
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

    describe "selecting a previous run" do
      def seed_partial_run(keys:, score: 1.0, at: 1.minute.ago)
        run =
          EvalEngine::Run.create!(
            eval_name: "is_ebike_manufacturer",
            status: :completed,
            started_at: at - 1.second,
            finished_at: at
          )
        keys.each do |key|
          EvalEngine::RunExample.create!(
            run: run,
            example_key: key,
            status: :completed,
            score: score,
            finished_at: at,
            started_at: at - 1.second
          )
        end
        run
      end

      it "links each row in the recent runs table back to the eval show with run_id" do
        run = seed_partial_run(keys: %w[amazon blixbike])

        get "/eval_engine/is_ebike_manufacturer"

        expect(response.body).to include("href=\"/eval_engine/is_ebike_manufacturer?run_id=#{run.id}\"")
      end

      it "filters the examples table to the selected run and greys out the others" do
        run = seed_partial_run(keys: %w[amazon])

        get "/eval_engine/is_ebike_manufacturer", params: { run_id: run.id }

        expect(response.body).to include("showing run started")
        expect(response.body).to include("ee-row--muted")
        expect(response.body).to include("not in this run")
        expect(response.body).to include("href=\"/eval_engine/is_ebike_manufacturer/examples/amazon?run_id=#{run.id}\"")
      end

      it "marks the selected run's row in recent runs and disables its link" do
        run = seed_partial_run(keys: %w[amazon])

        get "/eval_engine/is_ebike_manufacturer", params: { run_id: run.id }

        expect(response.body).to include("ee-row--current")
        expect(response.body).to include("ee-link--current")
        expect(response.body).not_to include("href=\"/eval_engine/is_ebike_manufacturer?run_id=#{run.id}\"")
      end

      it "404s when the requested run_id is not in this eval's recent runs" do
        get "/eval_engine/is_ebike_manufacturer", params: { run_id: 999_999 }

        expect(response).to have_http_status(:not_found)
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
