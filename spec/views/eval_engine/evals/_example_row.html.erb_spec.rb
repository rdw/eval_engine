require "rails_helper"

RSpec.describe "eval_engine/evals/_example_row.html.erb", type: :view do
  before { view.singleton_class.send(:include, EvalEngine::Engine.routes.url_helpers) }

  def row_for(key:, latest: nil, in_run: true, last_run_at: nil)
    { example: nil, latest: latest, in_run: in_run, key: key, last_run_at: last_run_at }
  end

  it "renders a tr with dom id eval_engine_example_row_<key>" do
    render partial: "eval_engine/evals/example_row",
           locals: { row: row_for(key: "amazon"), eval_name: "is_ebike_manufacturer" }

    expect(rendered).to include('id="eval_engine_example_row_amazon"')
  end

  it "marks the row muted and labels it 'not in this run' when in_run is false" do
    render partial: "eval_engine/evals/example_row",
           locals: { row: row_for(key: "amazon", in_run: false), eval_name: "is_ebike_manufacturer" }

    expect(rendered).to include("ee-row--muted")
    expect(rendered).to include("not in this run")
  end

  it "renders the example status pill from the latest RunExample when in_run is true" do
    run =
      EvalEngine::Run.create!(
        eval_name: "is_ebike_manufacturer",
        status: :completed,
        started_at: 1.minute.ago,
        finished_at: Time.current
      )
    re =
      EvalEngine::RunExample.create!(
        run: run,
        example_key: "amazon",
        status: :completed,
        score: 1.0,
        finished_at: Time.current,
        started_at: 1.second.ago
      )

    render partial: "eval_engine/evals/example_row",
           locals: {
             row: row_for(key: "amazon", latest: re, in_run: true, last_run_at: re.finished_at),
             eval_name: "is_ebike_manufacturer"
           }

    expect(rendered).to include("completed")
    expect(rendered).to include("1.000")
  end
end
