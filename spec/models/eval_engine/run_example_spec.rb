require "rails_helper"

RSpec.describe EvalEngine::RunExample, type: :model do
  let(:run) { EvalEngine::Run.create!(eval_name: "is_ebike_manufacturer", status: :running, started_at: Time.current) }

  describe "persistence" do
    it "round-trips JSON columns through the database" do
      example =
        described_class.create!(
          run: run,
          example_key: "blixbike",
          status: :completed,
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
        status: "completed",
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

      example = described_class.create!(run: run, example_key: "k", status: :completed, score: 0.5, score_tree: tree)

      expect(example.reload.score_tree).to eq(tree)
    end
  end

  describe "status enum" do
    it "exposes predicate methods and scopes for completed and errored" do
      done = described_class.create!(run: run, example_key: "ok", status: :completed, score: 0.7)
      bad = described_class.create!(run: run, example_key: "bad", status: :errored, score: 0.0, error: "boom")

      expect(done).to be_completed
      expect(bad).to be_errored
      expect(described_class.completed).to contain_exactly(done)
      expect(described_class.errored).to contain_exactly(bad)
    end

    it "tracks raised-vs-returned, not pass/fail of the score" do
      partial_score = described_class.create!(run: run, example_key: "p", status: :completed, score: 0.3)

      expect(partial_score).to be_completed
      expect(partial_score).not_to be_errored
    end
  end

  describe "belongs_to :run" do
    it "requires a run" do
      expect { described_class.create!(example_key: "x", status: :completed, score: 1.0) }.to raise_error(
        ActiveRecord::RecordInvalid,
        /Run must exist/
      )
    end
  end
end
