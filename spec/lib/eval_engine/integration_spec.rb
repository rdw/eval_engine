require "rails_helper"

RSpec.describe "E-bike manufacturer eval integration" do
  let(:tmp_dir) { Dir.mktmpdir("integration_spec") }
  let(:eval_name) { "is_ebike_manufacturer" }
  let(:examples_dir) { File.join(tmp_dir, eval_name, "examples") }
  let(:files_dir) { File.join(tmp_dir, eval_name, "files") }

  let(:example_data) do
    {
      "blixbike" => {
        "input" => {
          "url" => "https://blixbike.com/"
        },
        "expected" => "manufacturer"
      },
      "heybike" => {
        "input" => {
          "url" => "https://www.heybike.com/"
        },
        "expected" => "manufacturer"
      },
      "lectricebikes" => {
        "input" => {
          "url" => "https://lectricebikes.com/"
        },
        "expected" => "manufacturer"
      },
      "amazon" => {
        "input" => {
          "url" => "https://amazon.com/"
        },
        "expected" => "retailer"
      }
    }
  end

  before do
    FileUtils.mkdir_p(examples_dir)
    FileUtils.mkdir_p(files_dir)

    example_data.each { |key, data| File.write(File.join(examples_dir, "#{key}.yaml"), YAML.dump(data)) }

    stub_const(
      "IsEbikeManufacturerEval",
      Class.new(EvalEngine::Eval) do
        output_type :string, match: :exact

        define_method(:generate) do |input|
          case input["url"]
          when /blixbike/
            "manufacturer"
          when /heybike/
            "manufacturer"
          when /lectricebikes/
            "manufacturer"
          when /amazon/
            "retailer"
          end
        end
      end
    )
  end

  after { FileUtils.rm_rf(tmp_dir) }

  describe "loading examples from disk" do
    it "loads all four examples sorted alphabetically" do
      examples = EvalEngine::Example.load_all(examples_dir)

      expect(examples.length).to eq(4)
      expect(examples.map(&:key)).to eq(%w[amazon blixbike heybike lectricebikes])
    end

    it "each example has the correct input and expected values" do
      examples = EvalEngine::Example.load_all(examples_dir)
      by_key = examples.index_by(&:key)

      expect(by_key["blixbike"].input).to eq({ "url" => "https://blixbike.com/" })
      expect(by_key["blixbike"].expected).to eq("manufacturer")

      expect(by_key["amazon"].input).to eq({ "url" => "https://amazon.com/" })
      expect(by_key["amazon"].expected).to eq("retailer")
    end
  end

  describe "running the eval against all examples" do
    let(:eval_instance) { IsEbikeManufacturerEval.new(eval_root: tmp_dir) }
    let(:output_type) { IsEbikeManufacturerEval.output_type }
    let(:examples) { EvalEngine::Example.load_all(examples_dir) }

    it "generates correct output for each example" do
      results = examples.map { |ex| [ex.key, eval_instance.generate(ex.input)] }

      expect(results).to contain_exactly(
        %w[amazon retailer],
        %w[blixbike manufacturer],
        %w[heybike manufacturer],
        %w[lectricebikes manufacturer]
      )
    end

    it "scores 1.0 for every example when all outputs match" do
      examples.each do |ex|
        actual = eval_instance.generate(ex.input)
        score_tree = output_type.match(actual, ex.expected)

        expect(score_tree["score"]).to eq(1.0), "Expected score 1.0 for #{ex.key}, got #{score_tree["score"]}"
      end
    end

    it "computes an overall score of 1.0 when all examples pass" do
      scores =
        examples.map do |ex|
          actual = eval_instance.generate(ex.input)
          output_type.match(actual, ex.expected)["score"]
        end
      overall = scores.sum / scores.length

      expect(overall).to eq(1.0)
    end
  end

  describe "regression detection" do
    let(:output_type) { IsEbikeManufacturerEval.output_type }
    let(:examples) { EvalEngine::Example.load_all(examples_dir) }

    let(:regressed_eval_class) do
      Class.new(EvalEngine::Eval) do
        output_type :string, match: :exact

        define_method(:generate) do |input|
          case input["url"]
          when /blixbike/
            "manufacturer"
          when /heybike/
            "manufacturer"
          when /lectricebikes/
            "manufacturer"
          when /amazon/
            "marketplace"
          end
        end
      end
    end

    let(:regressed_instance) { regressed_eval_class.new(eval_root: tmp_dir) }

    it "scores 0.0 for the amazon example when it returns marketplace instead of retailer" do
      amazon = examples.find { |ex| ex.key == "amazon" }
      actual = regressed_instance.generate(amazon.input)
      score_tree = output_type.match(actual, amazon.expected)

      expect(actual).to eq("marketplace")
      expect(score_tree["score"]).to eq(0.0)
    end

    it "still scores 1.0 for the unaffected manufacturer examples" do
      manufacturer_examples = examples.reject { |ex| ex.key == "amazon" }

      manufacturer_examples.each do |ex|
        actual = regressed_instance.generate(ex.input)
        score_tree = output_type.match(actual, ex.expected)

        expect(score_tree["score"]).to eq(1.0), "Expected score 1.0 for #{ex.key}, got #{score_tree["score"]}"
      end
    end

    it "computes an overall score of 0.75 with one regression" do
      scores =
        examples.map do |ex|
          actual = regressed_instance.generate(ex.input)
          output_type.match(actual, ex.expected)["score"]
        end
      overall = scores.sum / scores.length

      expect(overall).to eq(0.75)
    end
  end

  describe "hash output type with multiple fields" do
    let(:examples_dir) { File.join(tmp_dir, "product_details", "examples") }

    let(:fake_embeddings) { { "Electronics & Gadgets" => [0.9, 0.3, 0.0], "Electronics" => [0.85, 0.1, 0.0] } }

    let(:product_eval_class) do
      Class.new(EvalEngine::Eval) do
        output_type :hash do
          field :name, :string, match: :exact
          field :category, :string, match: :soft
          field :price, :integer, tolerance: 5
        end

        define_method(:generate) do |input|
          case input["url"]
          when /widget/
            { "name" => "Super Widget", "category" => "Electronics & Gadgets", "price" => 29 }
          when /gizmo/
            { "name" => "Mega Gizmo", "category" => "Electronics", "price" => 50 }
          end
        end
      end
    end

    let(:product_output_type) { product_eval_class.output_type }

    before do
      FileUtils.mkdir_p(examples_dir)

      EvalEngine.configure { |c| c.embedding_fn = ->(text) { fake_embeddings.fetch(text, [0.0, 0.0, 0.0]) } }

      File.write(
        File.join(examples_dir, "widget.yaml"),
        YAML.dump(
          "input" => {
            "url" => "https://store.com/widget"
          },
          "expected" => {
            "name" => "Super Widget",
            "category" => "Electronics & Gadgets",
            "price" => 29
          }
        )
      )

      File.write(
        File.join(examples_dir, "gizmo.yaml"),
        YAML.dump(
          "input" => {
            "url" => "https://store.com/gizmo"
          },
          "expected" => {
            "name" => "Mega Gizmo",
            "category" => "Electronics & Gadgets",
            "price" => 49
          }
        )
      )
    end

    after { EvalEngine.instance_variable_set(:@configuration, nil) }

    it "returns a score tree with children for each field" do
      example = EvalEngine::Example.load_from_file(File.join(examples_dir, "widget.yaml"))
      eval_instance = product_eval_class.new(eval_root: tmp_dir)
      actual = eval_instance.generate(example.input)
      score_tree = product_output_type.match(actual, example.expected)

      expect(score_tree).to have_key("score")
      expect(score_tree).to have_key("children")
      expect(score_tree["children"]).to have_key("name")
      expect(score_tree["children"]).to have_key("category")
      expect(score_tree["children"]).to have_key("price")
    end

    it "scores 1.0 for an exact match across all fields" do
      example = EvalEngine::Example.load_from_file(File.join(examples_dir, "widget.yaml"))
      eval_instance = product_eval_class.new(eval_root: tmp_dir)
      actual = eval_instance.generate(example.input)
      score_tree = product_output_type.match(actual, example.expected)

      expect(score_tree["score"]).to eq(1.0)
      expect(score_tree["children"]["name"]["score"]).to eq(1.0)
      expect(score_tree["children"]["category"]["score"]).to eq(1.0)
      expect(score_tree["children"]["price"]["score"]).to eq(1.0)
    end

    it "gives partial credit for soft-matched and tolerance-matched fields" do
      example = EvalEngine::Example.load_from_file(File.join(examples_dir, "gizmo.yaml"))
      eval_instance = product_eval_class.new(eval_root: tmp_dir)
      actual = eval_instance.generate(example.input)
      score_tree = product_output_type.match(actual, example.expected)

      expect(score_tree["children"]["name"]["score"]).to eq(1.0)

      category_score = score_tree["children"]["category"]["score"]
      expect(category_score).to be > 0.0
      expect(category_score).to be < 1.0

      expect(score_tree["children"]["price"]["score"]).to eq(1.0)
    end

    it "computes the overall score as a weighted average of field scores" do
      example = EvalEngine::Example.load_from_file(File.join(examples_dir, "gizmo.yaml"))
      eval_instance = product_eval_class.new(eval_root: tmp_dir)
      actual = eval_instance.generate(example.input)
      score_tree = product_output_type.match(actual, example.expected)

      child_scores = score_tree["children"].values.map { |c| c["score"] }
      expected_overall = child_scores.sum / child_scores.length

      expect(score_tree["score"]).to be_within(0.0001).of(expected_overall)
    end
  end

  describe "eval_name derivation in context" do
    it "derives the correct name for IsEbikeManufacturerEval" do
      expect(IsEbikeManufacturerEval.eval_name).to eq("is_ebike_manufacturer")
    end

    it "uses eval_name to locate the files directory" do
      eval_instance = IsEbikeManufacturerEval.new(eval_root: tmp_dir)

      expect(eval_instance.files_path).to eq(File.join(tmp_dir, "is_ebike_manufacturer", "files", ""))
    end

    it "uses eval_name to locate the examples directory" do
      computed_dir = EvalEngine::Example.examples_dir_for(tmp_dir, IsEbikeManufacturerEval.eval_name)

      expect(computed_dir).to eq(examples_dir)
    end
  end

  describe "end-to-end: create_example round-trips through load" do
    before do
      @original_eval_root = EvalEngine.configuration.eval_root
      EvalEngine.configuration.eval_root = tmp_dir
    end

    after { EvalEngine.configuration.eval_root = @original_eval_root }

    it "creates an example via the API and loads it back" do
      EvalEngine.create_example(
        "is_ebike_manufacturer",
        "https://radpowerbikes.com/",
        input: {
          "url" => "https://radpowerbikes.com/"
        },
        expected: "manufacturer"
      )

      examples = EvalEngine::Example.load_all(examples_dir)
      rad = examples.find { |ex| ex.key == "radpowerbikes_com" }

      expect(rad).not_to be_nil
      expect(rad.input).to eq({ "url" => "https://radpowerbikes.com/" })
      expect(rad.expected).to eq("manufacturer")
    end
  end
end
