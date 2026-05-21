require "rails_helper"

RSpec.describe "eval_engine/evals/_run_row.html.erb", type: :view do
  before { view.singleton_class.send(:include, EvalEngine::Engine.routes.url_helpers) }

  let(:run) do
    EvalEngine::Run.create!(
      eval_name: "is_ebike_manufacturer",
      status: :running,
      started_at: 1.minute.ago,
      example_count: 4
    )
  end

  it "renders a tr with dom id run_<id>" do
    render partial: "eval_engine/evals/run_row", locals: { run: run, eval_name: run.eval_name }

    expect(rendered).to include(%(id="run_#{run.id}"))
  end

  it "links the Started cell back to the eval show page with run_id" do
    render partial: "eval_engine/evals/run_row", locals: { run: run, eval_name: run.eval_name }

    expect(rendered).to include(%(href="/eval_engine/is_ebike_manufacturer?run_id=#{run.id}"))
  end

  it "renders the started timestamp as a disabled span when the row is the currently-selected one" do
    render partial: "eval_engine/evals/run_row",
           locals: { run: run, eval_name: run.eval_name, selected_run_id: run.id }

    expect(rendered).to include("ee-row--current")
    expect(rendered).to include("ee-link--current")
    expect(rendered).not_to include(%(href="/eval_engine/is_ebike_manufacturer?run_id=#{run.id}"))
  end
end
