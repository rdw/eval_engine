module EvalEngine
  module DiffPresentationHelper
    def format_score(score)
      return "—" if score.nil?

      format("%.3f", score.to_f)
    end

    def score_class(score)
      return "ee-score--missing" if score.nil?
      return "ee-score--high" if score >= 0.9
      return "ee-score--mid" if score >= 0.5

      "ee-score--low"
    end

    def diff_row_color(score)
      return "hsl(0, 0%, 95%)" if score.nil?

      clamped = score.to_f.clamp(0.25, 1.0)
      hue = 120 * (clamped - 0.25) / 0.75
      "hsl(#{hue.round(1)}, 70%, 92%)"
    end

    def format_diff_value(value)
      return tag.span("—", class: "ee-diff__missing") if value.nil?

      str = value.is_a?(String) ? value : JSON.pretty_generate(value)
      tag.pre(str, class: "ee-diff__value")
    end
  end
end
