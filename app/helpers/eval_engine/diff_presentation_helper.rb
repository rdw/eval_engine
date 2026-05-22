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

    def render_diff_for(output_type:, eval_name:, score_tree:, expected:, output:)
      if output_type.nil?
        raise DiffRendering::ConfigurationError,
              "Cannot render diff: output_type is nil for eval '#{eval_name}'. " \
                "This usually means the eval class did not call `output_type` at the class level. " \
                "Add an `output_type :string` (or similar) declaration."
      end

      path = output_type.diff_partial_path
      unless path.is_a?(String) && !path.empty?
        raise DiffRendering::ConfigurationError,
              "Cannot render diff: #{matcher_label(output_type)}#diff_partial_path returned " \
                "#{path.inspect} (expected a non-empty String). " \
                "Either remove the method to use the default walker, or return a partial path like " \
                "\"evals/diffs/weighted_rubric\"."
      end

      render partial: path, locals: {
        output_type: output_type,
        eval_name: eval_name,
        score_tree: score_tree,
        expected: expected,
        output: output
      }
    rescue ActionView::MissingTemplate => e
      raise DiffRendering::ConfigurationError,
            "Cannot render diff: partial #{path.inspect} not found (returned by " \
              "#{matcher_label(output_type)}#diff_partial_path). #{e.message}. " \
              "Fix the matcher's return value or create the partial."
    end

    private

    def matcher_label(output_type)
      if output_type.is_a?(EvalEngine::Types::CustomType) && output_type.matcher
        output_type.matcher.class.name
      else
        output_type.class.name
      end
    end
  end
end
