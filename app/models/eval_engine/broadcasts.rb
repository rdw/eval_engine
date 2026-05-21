module EvalEngine
  module Broadcasts
    module_function

    def broadcast_example_row(run_example)
      eval_name = run_example.run.eval_name
      Turbo::StreamsChannel.broadcast_replace_to(
        [eval_name, "examples"],
        target: EvalsHelper.example_row_dom_id(run_example.example_key),
        html: render_partial("eval_engine/evals/example_row", row: row_for(run_example), eval_name: eval_name)
      )
    end

    def broadcast_run_prepend(run)
      Turbo::StreamsChannel.broadcast_prepend_to(
        [run.eval_name, "runs"],
        target: "eval_engine_runs_table",
        html: render_partial("eval_engine/evals/run_row", run: run, eval_name: run.eval_name)
      )
    end

    def broadcast_run_replace(run)
      Turbo::StreamsChannel.broadcast_replace_to(
        [run.eval_name, "runs"],
        target: ActionView::RecordIdentifier.dom_id(run),
        html: render_partial("eval_engine/evals/run_row", run: run, eval_name: run.eval_name)
      )
    end

    def render_partial(partial, **locals)
      ApplicationController.renderer.render(partial: partial, locals: locals)
    end

    def row_for(run_example)
      {
        latest: run_example,
        in_run: true,
        key: run_example.example_key,
        last_run_at: run_example.finished_at
      }
    end
  end
end
