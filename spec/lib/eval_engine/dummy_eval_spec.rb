require "rails_helper"
require_relative "../../dummy/eval/is_ebike_manufacturer/is_ebike_manufacturer_eval"

RSpec.describe IsEbikeManufacturerEval do
  let(:eval_root) { Rails.root.join("eval").to_s }
  let(:eval_instance) { described_class.new(eval_root: eval_root) }
  let(:examples_dir) { EvalEngine::Example.examples_dir_for(eval_root, described_class.eval_name) }
  let(:examples) { EvalEngine::Example.load_all(examples_dir) }

  describe "type declarations" do
    it "declares an input_type" do
      input_type = described_class.input_type
      expect(input_type).to be_a(EvalEngine::Types::HashType)
      expect(input_type.fields).to have_key(:url)
    end

    it "declares an output_type" do
      output_type = described_class.output_type
      expect(output_type).to be_a(EvalEngine::Types::StringType)
    end
  end

  describe "input validation" do
    it "validates well-formed inputs" do
      examples.each { |example| expect { described_class.input_type.validate!(example.input) }.not_to raise_error }
    end

    it "rejects inputs missing the url field" do
      expect { described_class.input_type.validate!({ "name" => "oops" }) }.to raise_error(
        EvalEngine::Types::ValidationError,
        /url: Missing required field/
      )
    end

    it "rejects non-hash inputs" do
      expect { described_class.input_type.validate!("not a hash") }.to raise_error(EvalEngine::Types::ValidationError)
    end
  end

  describe "running all examples" do
    it "loads four examples from the dummy app's eval directory" do
      expect(examples.length).to eq(4)
      expect(examples.map(&:key)).to contain_exactly("amazon", "blixbike", "heybike", "lectricebikes")
    end

    it "generates correct output for each example" do
      output_type = described_class.output_type

      examples.each do |example|
        output = eval_instance.generate(example.input)
        score_tree = output_type.match(output, example.expected)

        expect(score_tree["score"]).to eq(1.0),
        "#{example.key}: expected 1.0, got #{score_tree["score"]} " \
          "(output=#{output.inspect}, expected=#{example.expected.inspect})"
      end
    end

    it "computes a perfect overall score" do
      output_type = described_class.output_type

      scores =
        examples.map do |example|
          output = eval_instance.generate(example.input)
          output_type.match(output, example.expected)["score"]
        end

      expect(scores.sum / scores.length).to eq(1.0)
    end
  end

  describe "file access" do
    it "reads cached HTML files from the eval's files directory" do
      html = eval_instance.read_file("cache/blixbike.com.html")
      expect(html).to include("Blix Bike")
    end
  end
end
