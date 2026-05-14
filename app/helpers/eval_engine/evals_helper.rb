module EvalEngine
  module EvalsHelper
    def format_score(score)
      return "—" if score.nil?

      format("%.3f", score.to_f)
    end

    def score_cell(result)
      return tag.span("—", class: "ee-score ee-score--missing") if result.nil? || result.mean.nil?

      tag.span(format_score(result.mean), class: "ee-score #{score_class(result.mean)}")
    end

    def example_score_cell(run_example)
      return tag.span("not yet run", class: "ee-score ee-score--missing") if run_example.nil?
      return tag.span("ERROR", class: "ee-score ee-score--error") if run_example.errored?

      tag.span(format_score(run_example.score), class: "ee-score #{score_class(run_example.score)}")
    end

    def score_class(score)
      return "ee-score--missing" if score.nil?
      return "ee-score--high" if score >= 0.9
      return "ee-score--mid" if score >= 0.5

      "ee-score--low"
    end

    def example_total(result)
      return 0 if result.nil?

      result.per_example.length + result.missing_keys.length
    end

    def coverage_text(result)
      return "" if result.nil?

      total = example_total(result)
      "#{result.per_example.length}/#{total} examples"
    end

    def checkpoint_detail(checkpoint)
      return "(no checkpoint set)" if checkpoint.nil?

      "#{coverage_text(checkpoint)} • snapshot @ #{checkpoint.as_of.iso8601}"
    end

    def status_pill(status)
      tag.span(status, class: "ee-pill ee-pill--#{status}")
    end

    def duration_text(run)
      return "—" unless run.started_at && run.finished_at

      seconds = run.finished_at - run.started_at
      seconds < 60 ? format("%.1fs", seconds) : format("%dm %ds", seconds / 60, seconds % 60)
    end

    def preview(value, limit: 80)
      str = value.is_a?(String) ? value : value.to_json
      str = "#{str[0, limit]}…" if str.length > limit
      tag.code(str, class: "ee-preview")
    end
  end
end
