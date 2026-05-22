require "rails_helper"

RSpec.describe EvalEngine::EvalsHelper, type: :helper do
  describe "#render_diff_for" do
    let(:locals) { { score_tree: { "score" => 1.0 }, expected: "a", output: "a" } }

    it "renders the type's diff partial with the given locals (happy path with default walker)" do
      output_type = EvalEngine::Types::StringType.new

      html = helper.render_diff_for(output_type: output_type, eval_name: "is_ebike_manufacturer", **locals)

      expect(html).to include("ee-diff")
    end

    it "raises ConfigurationError naming the eval when output_type is nil" do
      expect {
        helper.render_diff_for(output_type: nil, eval_name: "is_ebike_manufacturer", **locals)
      }.to raise_error(EvalEngine::DiffRendering::ConfigurationError, /output_type is nil.*is_ebike_manufacturer/m)
    end

    it "exposes the four DiffPresentation primitives to view contexts" do
      expect(helper).to respond_to(:format_score, :score_class, :diff_row_color, :format_diff_value)
    end

    it "raises ConfigurationError naming the matcher class when diff_partial_path returns a non-String" do
      matcher = Class.new do
        def self.name = "BadMatcher"
        def diff_partial_path = nil
      end.new
      output_type = EvalEngine::Types::CustomType.new(matcher: matcher)

      expect {
        helper.render_diff_for(output_type: output_type, eval_name: "is_ebike_manufacturer", **locals)
      }.to raise_error(EvalEngine::DiffRendering::ConfigurationError, /BadMatcher#diff_partial_path returned nil/)
    end

    it "raises ConfigurationError naming the missing path when the partial doesn't exist" do
      matcher = Class.new do
        def self.name = "MissingPartialMatcher"
        def diff_partial_path = "nonexistent/diffs/foo"
      end.new
      output_type = EvalEngine::Types::CustomType.new(matcher: matcher)

      expected_msg = %r{"nonexistent/diffs/foo" not found.*MissingPartialMatcher}m
      expect {
        helper.render_diff_for(output_type: output_type, eval_name: "is_ebike_manufacturer", **locals)
      }.to raise_error(EvalEngine::DiffRendering::ConfigurationError, expected_msg)
    end
  end
end
