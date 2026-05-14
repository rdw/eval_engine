module EvalEngine
  class Engine < ::Rails::Engine
    isolate_namespace EvalEngine

    initializer "eval_engine.default_configuration" do
      EvalEngine.configuration.eval_root ||= Rails.root.join("eval").to_s
    end
  end
end
