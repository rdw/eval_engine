EvalEngine::Engine.routes.draw do
  root "evals#index"
  get ":name", to: "evals#show", as: :eval, constraints: { name: %r{[^/]+} }
end
