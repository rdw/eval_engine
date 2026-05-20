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

    DELTA_NOISE_FLOOR = 0.01

    def delta_cell(latest, checkpoint)
      return "" if latest.nil? || checkpoint.nil? || latest.mean.nil? || checkpoint.mean.nil?

      delta = latest.mean - checkpoint.mean
      return "" if delta.abs < DELTA_NOISE_FLOOR

      tag.span(format("%+.2f", delta), class: "ee-delta", style: "background-color: #{delta_color(delta)}")
    end

    def delta_color(delta)
      hue = delta.positive? ? 120 : 0
      magnitude = delta.abs.clamp(0.0, 1.0)
      saturation = 30 + (magnitude * 50)
      lightness = 92 - (magnitude * 12)
      "hsl(#{hue}, #{saturation.round(1)}%, #{lightness.round(1)}%)"
    end

    def sort_link(column, label, eval_name:, current_sort:, current_dir:)
      active = current_sort == column.to_s
      next_dir = active && current_dir == "asc" ? "desc" : "asc"
      arrow = active ? (current_dir == "desc" ? " ↓" : " ↑") : ""
      link_to "#{label}#{arrow}", eval_path(eval_name, sort: column, dir: next_dir), class: "ee-sort-link"
    end

    def example_duration(run_example)
      return "—" unless run_example&.started_at && run_example&.finished_at

      seconds = run_example.finished_at - run_example.started_at
      seconds < 1 ? format("%dms", (seconds * 1000).round) : format("%.2fs", seconds)
    end

    def example_status_pill(run_example)
      return tag.span("not yet run", class: "ee-pill ee-pill--missing") if run_example.nil?

      status_pill(run_example.status)
    end

    def diff_rows(score_tree, expected, output)
      return [] if score_tree.nil?

      rows = []
      walk_diff(rows, "", score_tree, expected, output)
      rows
    end

    def format_diff_value(value)
      return tag.span("—", class: "ee-diff__missing") if value.nil?

      str = value.is_a?(String) ? value : JSON.pretty_generate(value)
      tag.pre(str, class: "ee-diff__value")
    end

    def diff_row_color(score)
      return "hsl(0, 0%, 95%)" if score.nil?

      clamped = score.to_f.clamp(0.25, 1.0)
      hue = 120 * (clamped - 0.25) / 0.75
      "hsl(#{hue.round(1)}, 70%, 92%)"
    end

    def format_json_block(value)
      return tag.span("(none)", class: "ee-empty") if value.nil?

      str = value.is_a?(String) ? value : JSON.pretty_generate(value)
      tag.pre(str, class: "ee-codeblock")
    end

    private

    def walk_diff(rows, path, node, expected, output)
      children = node["children"]
      if children.is_a?(Hash)
        walk_hash_children(rows, path, children, expected, output)
      elsif children.is_a?(Array)
        walk_array_children(rows, path, node, expected, output)
      else
        rows << { path: path.empty? ? "(value)" : path, score: node["score"], expected: expected, output: output }
      end
    end

    def walk_hash_children(rows, path, children, expected, output)
      children.each do |key, child|
        child_path = path.empty? ? key : "#{path}.#{key}"
        walk_diff(rows, child_path, child, dig_indifferent(expected, key), dig_indifferent(output, key))
      end
    end

    def walk_array_children(rows, path, node, expected, output)
      alignment = node["alignment"]
      node["children"].each_with_index do |child, i|
        e_idx, a_idx = alignment ? [alignment[i]["expected"], alignment[i]["actual"]] : [i, i]
        e_val = e_idx && expected.is_a?(Array) ? expected[e_idx] : nil
        a_val = a_idx && output.is_a?(Array) ? output[a_idx] : nil
        walk_diff(rows, "#{path}[#{i}]", child, e_val, a_val)
      end
    end

    def dig_indifferent(value, key)
      return nil unless value.is_a?(Hash)
      return value[key] if value.key?(key)

      value[key.to_sym] if key.is_a?(String)
    end
  end
end
