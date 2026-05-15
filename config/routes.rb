EvalEngine::Engine.routes.draw do
  root "evals#index"

  constraints name: %r{[^/]+} do
    get ":name", to: "evals#show", as: :eval
    post ":name/runs", to: "runs#create", as: :eval_runs
    delete ":name/runs/:id", to: "runs#destroy", as: :eval_run
    post ":name/checkpoint", to: "checkpoints#create", as: :eval_checkpoint
    post ":name/rescore", to: "evals#rescore", as: :eval_rescore
    get ":name/examples/:key", to: "examples#show", as: :eval_example, constraints: { key: %r{[^/]+} }
  end
end
