require "rails_helper"

RSpec.describe "EvalEngine.connects_to" do
  let(:engine_config) { EvalEngine::Engine.config.eval_engine }
  let(:copy_initializer) { EvalEngine::Engine.instance.initializers.find { |i| i.name == "eval_engine.config" } }

  before do
    @original_module_value = EvalEngine.connects_to
    @original_engine_value = engine_config.connects_to
  end

  after do
    EvalEngine.connects_to = @original_module_value
    engine_config.connects_to = @original_engine_value
  end

  it "is a mattr_accessor on the EvalEngine module" do
    EvalEngine.connects_to = { database: { writing: :evals } }
    expect(EvalEngine.connects_to).to eq(database: { writing: :evals })
  end

  it "exposes config.eval_engine as an ActiveSupport::OrderedOptions" do
    expect(engine_config).to be_a(ActiveSupport::OrderedOptions)
  end

  it "registers an initializer that copies config.eval_engine.* onto the module" do
    expect(copy_initializer).not_to be_nil
  end

  it "flows config.eval_engine.connects_to onto EvalEngine.connects_to when the initializer runs" do
    EvalEngine.connects_to = nil
    engine_config.connects_to = { database: { writing: :evals } }

    copy_initializer.run(Rails.application)

    expect(EvalEngine.connects_to).to eq(database: { writing: :evals })
  end

  it "ignores unknown config.eval_engine settings without raising" do
    engine_config.nonexistent_setting = "ignored"

    expect { copy_initializer.run(Rails.application) }.not_to raise_error
  end
end
