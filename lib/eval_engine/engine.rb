require "turbo-rails"

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

    initializer "eval_engine.diff_presentation_helper" do
      # Pushes DiffPresentationHelper into every full-stack controller so
      # host-app custom diff partials can call format_score, diff_row_color,
      # etc. Only hooks ActionController::Base; API-only hosts
      # (ActionController::API) won't receive it, which is fine since the
      # engine renders HTML — if such a host ever renders engine views,
      # add `helper EvalEngine::DiffPresentationHelper` manually there.
      ActiveSupport.on_load(:action_controller_base) do
        helper EvalEngine::DiffPresentationHelper
      end
    end
  end
end
