require "rails_helper"

RSpec.describe EvalEngine::RunExample, type: :model do
  let(:run) { EvalEngine::Run.create!(eval_name: "is_ebike_manufacturer", status: :running, started_at: Time.current) }

  describe "persistence" do
    it "round-trips JSON columns through the database" do
      example =
        described_class.create!(
          run: run,
          example_key: "blixbike",
          status: :passed,
          started_at: Time.current,
          finished_at: Time.current,
          input: {
            "url" => "https://blixbike.com/"
          },
          expected: "manufacturer",
          output: "manufacturer",
          score_tree: {
            "score" => 1.0
          },
          score: 1.0
        )

      example.reload

      expect(example).to have_attributes(
        example_key: "blixbike",
        status: "passed",
        input: {
          "url" => "https://blixbike.com/"
        },
        expected: "manufacturer",
        output: "manufacturer",
        score_tree: {
          "score" => 1.0
        },
        score: 1.0
      )
    end

    it "stores nested score_tree structures unchanged" do
      tree = { "score" => 0.5, "children" => { "name" => { "score" => 1.0 }, "price" => { "score" => 0.0 } } }

      example = described_class.create!(run: run, example_key: "k", status: :failed, score: 0.5, score_tree: tree)

      expect(example.reload.score_tree).to eq(tree)
    end
  end

  describe "status enum" do
    it "exposes predicate methods for passed/failed/error" do
      passed = described_class.create!(run: run, example_key: "p", status: :passed, score: 1.0)
      failed = described_class.create!(run: run, example_key: "f", status: :failed, score: 0.5)
      errored = described_class.create!(run: run, example_key: "e", status: :error, score: 0.0, error: "boom")

      expect(passed).to be_passed
      expect(failed).to be_failed
      expect(errored).to be_error
    end
  end

  describe "belongs_to :run" do
    it "requires a run" do
      expect { described_class.create!(example_key: "x", status: :passed, score: 1.0) }.to raise_error(
        ActiveRecord::RecordInvalid,
        /Run must exist/
      )
    end
  end
end
