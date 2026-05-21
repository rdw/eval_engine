module EvalEngine
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    helper EvalsHelper
    helper Turbo::Engine.helpers
  end
end
