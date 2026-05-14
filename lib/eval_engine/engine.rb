module EvalEngine
  class Engine < ::Rails::Engine
    isolate_namespace EvalEngine

    config.eval_engine = ActiveSupport::OrderedOptions.new

    initializer "eval_engine.config" do
      config.eval_engine.each do |name, value|
        EvalEngine.public_send(:"#{name}=", value) if EvalEngine.respond_to?(:"#{name}=")
      end
    end

    initializer "eval_engine.default_configuration" do
      EvalEngine.configuration.eval_root ||= Rails.root.join("eval").to_s
    end
  end
end
