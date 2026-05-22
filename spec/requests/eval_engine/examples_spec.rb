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

      expect(response.body).to include("Run errored")
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

    describe "selecting a historical run" do
      def run_id_href(run_id)
        "href=\"/eval_engine/is_ebike_manufacturer/examples/amazon?run_id=#{run_id}\""
      end

      def seed_run(score:, output:, at:)
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
          output: output,
          expected: "retailer",
          score: score,
          score_tree: {
            "score" => score
          },
          started_at: at - 1.second,
          finished_at: at
        )
        run
      end

      it "shows the latest run's diff by default and links the older history rows with run_id" do
        old_run = seed_run(score: 0.25, output: "manufacturer", at: 10.minutes.ago)
        seed_run(score: 1.0, output: "retailer", at: 1.minute.ago)

        get "/eval_engine/is_ebike_manufacturer/examples/amazon"

        expect(response.body).to include("hsl(120.0, 70%, 92%)")
        expect(response.body).to include(run_id_href(old_run.id))
      end

      it "switches to the requested historical run when ?run_id is given" do
        old_run = seed_run(score: 0.25, output: "manufacturer", at: 10.minutes.ago)
        seed_run(score: 1.0, output: "retailer", at: 1.minute.ago)

        get "/eval_engine/is_ebike_manufacturer/examples/amazon", params: { run_id: old_run.id }

        expect(response.body).to include("hsl(0.0, 70%, 92%)")
        expect(response.body).to include("manufacturer")
      end

      it "marks the currently shown row and disables its link" do
        old_run = seed_run(score: 0.25, output: "manufacturer", at: 10.minutes.ago)
        latest_run = seed_run(score: 1.0, output: "retailer", at: 1.minute.ago)

        get "/eval_engine/is_ebike_manufacturer/examples/amazon", params: { run_id: old_run.id }

        expect(response.body).to include("ee-row--current")
        expect(response.body).to include("ee-link--current")
        expect(response.body).not_to include(run_id_href(old_run.id))
        expect(response.body).to include(run_id_href(latest_run.id))
      end

      it "404s when the requested run_id is not part of this example's history" do
        seed_run(score: 1.0, output: "retailer", at: 1.minute.ago)

        get "/eval_engine/is_ebike_manufacturer/examples/amazon", params: { run_id: 999_999 }

        expect(response).to have_http_status(:not_found)
      end
    end

    describe "custom matcher with diff_partial_path" do
      it "renders the matcher's partial instead of the default walker" do
        matcher = Class.new { def diff_partial_path = "fixtures/diffs/test_matcher" }.new
        custom_type = EvalEngine::Types::CustomType.new(matcher: matcher)
        eval_class = Class.new(EvalEngine::Eval)
        eval_class.define_singleton_method(:output_type) { custom_type }
        allow(EvalEngine::Loader).to receive(:load_eval).and_call_original
        allow(EvalEngine::Loader).to receive(:load_eval).with("is_ebike_manufacturer").and_return(eval_class)

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
          score: 0.42,
          score_tree: {
            "score" => 0.42
          },
          finished_at: Time.current,
          started_at: 1.second.ago
        )

        get "/eval_engine/is_ebike_manufacturer/examples/amazon"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("FIXTURE DIFF RENDERED FROM CUSTOM MATCHER PARTIAL")
        expect(response.body).to include("score: 0.420")
        expect(response.body).not_to include("ee-table ee-diff")
      end

      it "supports recursive dispatch: a custom collection partial renders children via render_diff_for" do
        matcher_class = Class.new do
          def diff_partial_path = "fixtures/diffs/recursive_collection"

          def children_for_diff(score_tree, expected, output)
            score_tree["children"].each_with_index.map do |child_st, i|
              {
                label: "item #{i}",
                type: EvalEngine::Types::StringType.new,
                score_tree: child_st,
                expected: expected[i],
                output: output[i]
              }
            end
          end
        end
        custom_type = EvalEngine::Types::CustomType.new(matcher: matcher_class.new)
        eval_class = Class.new(EvalEngine::Eval)
        eval_class.define_singleton_method(:output_type) { custom_type }
        allow(EvalEngine::Loader).to receive(:load_eval).and_call_original
        allow(EvalEngine::Loader).to receive(:load_eval).with("is_ebike_manufacturer").and_return(eval_class)

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
          output: %w[foo wrong],
          expected: %w[foo right],
          score: 0.5,
          score_tree: {
            "score" => 0.5,
            "children" => [{ "score" => 1.0 }, { "score" => 0.0 }]
          },
          finished_at: Time.current,
          started_at: 1.second.ago
        )

        get "/eval_engine/is_ebike_manufacturer/examples/amazon"

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("RECURSIVE COLLECTION HEADER")
        expect(response.body).to include("overall score: 0.500")
        expect(response.body).to include("item 0")
        expect(response.body).to include("item 1")
        # Each child rendered via the default walker — table from StringType partial.
        expect(response.body.scan("ee-table ee-diff").length).to eq(2)
      end
    end
  end
end
