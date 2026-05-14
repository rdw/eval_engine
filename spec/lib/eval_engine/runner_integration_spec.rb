require "rails_helper"

RSpec.describe "Runner end-to-end on the dummy is_ebike_manufacturer eval" do
  let(:run) { EvalEngine.run("is_ebike_manufacturer", parallelism: 1) }

  after { Object.send(:remove_const, :IsEbikeManufacturerEval) if Object.const_defined?(:IsEbikeManufacturerEval) }

  it "loads the real eval from disk and persists a completed Run" do
    expect(run).to have_attributes(eval_name: "is_ebike_manufacturer", status: "completed", example_count: 4)
    expect(run.started_at).to be_present
    expect(run.finished_at).to be_present
  end

  it "creates one RunExample per example and snapshots input/expected/output/score" do
    examples = run.run_examples.index_by(&:example_key)

    expect(examples.keys).to contain_exactly("amazon", "blixbike", "heybike", "lectricebikes")
    examples.each_value { |ex| expect(ex).to be_completed }

    blixbike = examples.fetch("blixbike")
    expect(blixbike).to have_attributes(
      input: {
        "url" => "https://blixbike.com/"
      },
      expected: "manufacturer",
      output: "manufacturer",
      score: 1.0,
      score_tree: {
        "score" => 1.0
      }
    )

    amazon = examples.fetch("amazon")
    expect(amazon).to have_attributes(
      input: {
        "url" => "https://amazon.com/"
      },
      expected: "retailer",
      output: "retailer",
      score: 1.0
    )
  end

  it "scores 1.0 across all four examples (this eval's outputs match exactly)" do
    expect(run.run_examples.pluck(:score)).to all(eq(1.0))
  end
end
