require "rails_helper"

RSpec.describe EvalEngine::Types do
  describe EvalEngine::Types::StringType do
    context "exact match (default)" do
      subject(:type) { described_class.new }

      it "returns 1.0 for equal strings" do
        result = type.match("hello", "hello")
        expect(result).to eq("score" => 1.0)
      end

      it "returns 0.25 for different strings (legacy fixed_string floor — credit for being a string)" do
        result = type.match("hello", "world")
        expect(result).to eq("score" => 0.25)
      end

      it "returns 0.0 when actual is nil and expected is not" do
        result = type.match(nil, "hello")
        expect(result).to eq("score" => 0.0)
      end

      it "returns 0.0 when expected is nil and actual is not" do
        result = type.match("hello", nil)
        expect(result).to eq("score" => 0.0)
      end

      it "returns 1.0 when both are nil (legacy: nil-equals-nil)" do
        result = type.match(nil, nil)
        expect(result).to eq("score" => 1.0)
      end

      it "compares stringified values, so 3 matches '3'" do
        expect(type.match("3", 3)).to eq("score" => 1.0)
        expect(type.match(3, "3")).to eq("score" => 1.0)
      end
    end

    context "soft match" do
      subject(:type) { described_class.new(match: :soft) }

      let(:fake_embeddings) do
        {
          "manufacturer" => [1.0, 0.0, 0.0],
          "maker" => [0.9, 0.1, 0.0],
          "retailer" => [0.0, 0.0, 1.0],
          "hello" => [0.5, 0.5, 0.0]
        }
      end

      before do
        @original_embedding_fn = EvalEngine.configuration.embedding_fn
        EvalEngine.configure { |c| c.embedding_fn = ->(text) { fake_embeddings.fetch(text, [0.0, 0.0, 0.0]) } }
      end

      after { EvalEngine.configuration.embedding_fn = @original_embedding_fn }

      it "returns 1.0 for identical strings" do
        result = type.match("manufacturer", "manufacturer")
        expect(result["score"]).to eq(1.0)
      end

      it "returns a high score for similar embeddings" do
        result = type.match("manufacturer", "maker")
        expect(result["score"]).to be > 0.9
      end

      it "returns a low score for dissimilar embeddings" do
        result = type.match("manufacturer", "retailer")
        expect(result["score"]).to eq(0.0)
      end

      it "returns 0.0 when only one value is nil and 1.0 when both are" do
        expect(type.match(nil, "hello")["score"]).to eq(0.0)
        expect(type.match("hello", nil)["score"]).to eq(0.0)
        expect(type.match(nil, nil)["score"]).to eq(1.0)
      end

      it "raises ConfigurationError when no embedding_fn is configured" do
        EvalEngine.configuration.embedding_fn = nil
        expect { type.match("hello", "world") }.to raise_error(EvalEngine::ConfigurationError, /embedding function/)
      end
    end

    context "soft match with threshold" do
      let(:fake_embeddings) do
        {
          "manufacturer" => [1.0, 0.0, 0.0],
          "maker" => [0.9, 0.1, 0.0],
          "retailer" => [0.0, 0.0, 1.0],
          "hello" => [0.5, 0.5, 0.0]
        }
      end

      before do
        @original_embedding_fn = EvalEngine.configuration.embedding_fn
        EvalEngine.configure { |c| c.embedding_fn = ->(text) { fake_embeddings.fetch(text, [0.0, 0.0, 0.0]) } }
      end

      after { EvalEngine.configuration.embedding_fn = @original_embedding_fn }

      it "binarizes to 1.0 when similarity meets the threshold" do
        type = described_class.new(match: :soft, threshold: 0.8)
        # manufacturer vs maker has cosine ~0.994
        expect(type.match("manufacturer", "maker")["score"]).to eq(1.0)
      end

      it "binarizes to 0.0 when similarity is below the threshold" do
        type = described_class.new(match: :soft, threshold: 0.8)
        # manufacturer vs hello has cosine ~0.707
        expect(type.match("manufacturer", "hello")["score"]).to eq(0.0)
      end

      it "binarizes to 1.0 at exactly the threshold" do
        type = described_class.new(match: :soft, threshold: 0.7)
        # manufacturer vs hello has cosine ~0.707, just above 0.7
        expect(type.match("manufacturer", "hello")["score"]).to eq(1.0)
      end

      it "still returns 1.0 for identical strings" do
        type = described_class.new(match: :soft, threshold: 0.99)
        expect(type.match("manufacturer", "manufacturer")["score"]).to eq(1.0)
      end

      it "preserves nil handling regardless of threshold" do
        type = described_class.new(match: :soft, threshold: 0.5)
        expect(type.match(nil, "hello")["score"]).to eq(0.0)
        expect(type.match(nil, nil)["score"]).to eq(1.0)
      end
    end

    context "validation" do
      subject(:type) { described_class.new }

      it "accepts strings" do
        expect { type.validate!("hello") }.not_to raise_error
      end

      it "accepts nil" do
        expect { type.validate!(nil) }.not_to raise_error
      end

      it "rejects integers" do
        expect { type.validate!(42) }.to raise_error(EvalEngine::Types::ValidationError, /Expected string, got Integer/)
      end

      it "rejects other types" do
        expect { type.validate!([]) }.to raise_error(EvalEngine::Types::ValidationError)
      end
    end
  end

  describe EvalEngine::Types::IntegerType do
    context "exact match (no tolerance)" do
      subject(:type) { described_class.new }

      it "returns 1.0 for equal integers" do
        result = type.match(42, 42)
        expect(result).to eq("score" => 1.0)
      end

      it "returns 0.25 for different integers (legacy floor — credit for being a number)" do
        result = type.match(42, 43)
        expect(result).to eq("score" => 0.25)
      end

      it "returns 0.0 when actual is nil" do
        result = type.match(nil, 42)
        expect(result).to eq("score" => 0.0)
      end

      it "returns 0.0 when expected is nil" do
        result = type.match(42, nil)
        expect(result).to eq("score" => 0.0)
      end

      it "returns 0.0 for non-numeric actual" do
        result = type.match("42", 42)
        expect(result).to eq("score" => 0.0)
      end
    end

    context "with tolerance" do
      subject(:type) { described_class.new(tolerance: 5) }

      it "returns 1.0 when difference is within tolerance" do
        result = type.match(43, 45)
        expect(result["score"]).to eq(1.0)
      end

      it "returns 1.0 when difference equals tolerance" do
        result = type.match(40, 45)
        expect(result["score"]).to eq(1.0)
      end

      it "returns a partial score just outside tolerance" do
        result = type.match(38, 45)
        score = result["score"]
        expect(score).to be > 0.0
        expect(score).to be < 1.0
      end

      it "clamps to the 0.25 floor when far outside tolerance" do
        result = type.match(0, 45)
        expect(result["score"]).to eq(0.25)
      end

      [[7, 0.25], [6, 0.5], [5, 0.75], [4, 1.0], [3, 1.0], [2, 1.0], [1, 1.0], [0, 1.0]].each do |actual, expected|
        it "interpolates 0.25..1.0 for actual=#{actual} (tolerance: 3, expected: 1)" do
          result = described_class.new(tolerance: 3).match(actual, 1)
          expect(result["score"]).to eq(expected)
        end
      end
    end

    context "validation" do
      subject(:type) { described_class.new }

      it "accepts integers" do
        expect { type.validate!(10) }.not_to raise_error
      end

      it "accepts nil" do
        expect { type.validate!(nil) }.not_to raise_error
      end

      it "rejects floats" do
        expect { type.validate!(1.5) }.to raise_error(EvalEngine::Types::ValidationError, /Expected integer, got Float/)
      end

      it "rejects strings" do
        expect { type.validate!("10") }.to raise_error(EvalEngine::Types::ValidationError)
      end
    end
  end

  describe EvalEngine::Types::FloatType do
    context "exact match (zero tolerance)" do
      subject(:type) { described_class.new }

      it "returns 1.0 for equal floats" do
        result = type.match(3.14, 3.14)
        expect(result["score"]).to eq(1.0)
      end

      it "returns 0.25 for different floats with zero tolerance (legacy floor)" do
        result = type.match(3.14, 3.15)
        expect(result["score"]).to eq(0.25)
      end

      it "returns 0.0 when actual is nil" do
        result = type.match(nil, 3.14)
        expect(result["score"]).to eq(0.0)
      end

      it "returns 0.0 for non-numeric actual" do
        result = type.match("3.14", 3.14)
        expect(result["score"]).to eq(0.0)
      end
    end

    context "with tolerance" do
      subject(:type) { described_class.new(tolerance: 0.5) }

      it "returns 1.0 when difference is within tolerance" do
        result = type.match(3.0, 3.3)
        expect(result["score"]).to eq(1.0)
      end

      it "returns 1.0 when difference equals tolerance" do
        result = type.match(3.0, 3.5)
        expect(result["score"]).to eq(1.0)
      end

      it "returns a partial score just outside tolerance" do
        result = type.match(3.0, 3.7)
        score = result["score"]
        expect(score).to be > 0.0
        expect(score).to be < 1.0
      end

      it "clamps to the 0.25 floor when far outside tolerance" do
        result = type.match(0.0, 10.0)
        expect(result["score"]).to eq(0.25)
      end
    end

    context "validation" do
      subject(:type) { described_class.new }

      it "accepts floats" do
        expect { type.validate!(1.5) }.not_to raise_error
      end

      it "accepts integers (all Numeric)" do
        expect { type.validate!(42) }.not_to raise_error
      end

      it "accepts nil" do
        expect { type.validate!(nil) }.not_to raise_error
      end

      it "rejects strings" do
        expect { type.validate!("1.5") }.to raise_error(
          EvalEngine::Types::ValidationError,
          /Expected numeric, got String/
        )
      end
    end
  end

  describe EvalEngine::Types::BooleanType do
    subject(:type) { described_class.new }

    it "returns 1.0 for true/true" do
      result = type.match(true, true)
      expect(result).to eq("score" => 1.0)
    end

    it "returns 0.0 for true/false" do
      result = type.match(true, false)
      expect(result).to eq("score" => 0.0)
    end

    it "returns 0.0 for false/true" do
      result = type.match(false, true)
      expect(result).to eq("score" => 0.0)
    end

    it "returns 1.0 for false/false" do
      result = type.match(false, false)
      expect(result).to eq("score" => 1.0)
    end

    context "validation" do
      it "accepts true" do
        expect { type.validate!(true) }.not_to raise_error
      end

      it "accepts false" do
        expect { type.validate!(false) }.not_to raise_error
      end

      it "accepts nil" do
        expect { type.validate!(nil) }.not_to raise_error
      end

      it "rejects strings" do
        expect { type.validate!("true") }.to raise_error(EvalEngine::Types::ValidationError, /Expected boolean/)
      end

      it "rejects integers" do
        expect { type.validate!(1) }.to raise_error(EvalEngine::Types::ValidationError)
      end
    end
  end

  describe EvalEngine::Types::HashType do
    context "simple hash with two string fields" do
      subject(:type) do
        described_class.new(
          fields: {
            name: EvalEngine::Types::StringType.new,
            city: EvalEngine::Types::StringType.new
          }
        )
      end

      it "returns 1.0 when both fields match" do
        result = type.match({ name: "Alice", city: "Paris" }, { name: "Alice", city: "Paris" })
        expect(result["score"]).to eq(1.0)
      end

      it "averages a 1.0 match with the 0.25 string-mismatch floor" do
        result = type.match({ name: "Alice", city: "London" }, { name: "Alice", city: "Paris" })
        expect(result["score"]).to eq(0.625)
      end

      it "averages two 0.25 string-mismatch floors when both fields differ" do
        result = type.match({ name: "Bob", city: "London" }, { name: "Alice", city: "Paris" })
        expect(result["score"]).to eq(0.25)
      end

      it "includes children results keyed by field name as strings" do
        result = type.match({ name: "Alice", city: "Paris" }, { name: "Alice", city: "Paris" })
        expect(result["children"]).to include("name" => { "score" => 1.0 }, "city" => { "score" => 1.0 })
      end
    end

    context "weighted fields" do
      subject(:type) do
        described_class.new(
          fields: {
            important: EvalEngine::Types::StringType.new(weight: 3),
            minor: EvalEngine::Types::StringType.new(weight: 1)
          }
        )
      end

      it "weights the important field more heavily" do
        # important matches (1.0, weight 3); minor floor (0.25, weight 1) → (3.0 + 0.25) / 4 = 0.8125
        result = type.match({ important: "match", minor: "miss" }, { important: "match", minor: "hit" })
        expect(result["score"]).to eq(0.8125)
      end

      it "produces a low score when the important field mismatches" do
        # important floor (0.25, weight 3); minor matches (1.0, weight 1) → (0.75 + 1.0) / 4 = 0.4375
        result = type.match({ important: "miss", minor: "hit" }, { important: "match", minor: "hit" })
        expect(result["score"]).to eq(0.4375)
      end
    end

    context "indifferent access" do
      subject(:type) { described_class.new(fields: { name: EvalEngine::Types::StringType.new }) }

      it "matches string keys in actual against symbol keys in field definition" do
        result = type.match({ "name" => "Alice" }, { "name" => "Alice" })
        expect(result["score"]).to eq(1.0)
      end

      it "matches symbol keys in actual against string keys in field definition" do
        string_keyed_type = described_class.new(fields: { "name" => EvalEngine::Types::StringType.new })
        result = string_keyed_type.match({ name: "Alice" }, { name: "Alice" })
        expect(result["score"]).to eq(1.0)
      end
    end

    context "nested hashes" do
      subject(:type) do
        address_type =
          EvalEngine::Types::HashType.new(
            fields: {
              street: EvalEngine::Types::StringType.new,
              zip: EvalEngine::Types::StringType.new
            }
          )
        described_class.new(fields: { name: EvalEngine::Types::StringType.new, address: address_type })
      end

      it "matches nested hash fields recursively" do
        result =
          type.match(
            { name: "Alice", address: { street: "123 Main", zip: "90210" } },
            { name: "Alice", address: { street: "123 Main", zip: "90210" } }
          )
        expect(result["score"]).to eq(1.0)
      end

      it "produces partial score when nested field mismatches" do
        # address.street matches (1.0); address.zip floors (0.25) → address = 0.625.
        # name matches (1.0); top-level = (1.0 + 0.625) / 2 = 0.8125.
        result =
          type.match(
            { name: "Alice", address: { street: "123 Main", zip: "00000" } },
            { name: "Alice", address: { street: "123 Main", zip: "90210" } }
          )
        expect(result["score"]).to eq(0.8125)
        expect(result["children"]["address"]["score"]).to eq(0.625)
      end
    end

    context "nil actual" do
      subject(:type) do
        described_class.new(
          fields: {
            name: EvalEngine::Types::StringType.new,
            age: EvalEngine::Types::IntegerType.new
          }
        )
      end

      it "scores 0.0 for all children when actual is nil" do
        result = type.match(nil, { name: "Alice", age: 30 })
        expect(result["score"]).to eq(0.0)
        expect(result["children"]["name"]["score"]).to eq(0.0)
        expect(result["children"]["age"]["score"]).to eq(0.0)
      end
    end

    context "validation errors include field names" do
      subject(:type) { described_class.new(fields: { age: EvalEngine::Types::IntegerType.new }) }

      it "prefixes the field name in the error message" do
        expect { type.validate!({ age: "not_an_int" }) }.to raise_error(
          EvalEngine::Types::ValidationError,
          /age: Expected integer/
        )
      end
    end

    context "missing required fields" do
      subject(:type) do
        described_class.new(
          fields: {
            name: EvalEngine::Types::StringType.new,
            age: EvalEngine::Types::IntegerType.new
          }
        )
      end

      it "raises when a declared field is absent" do
        expect { type.validate!({ "name" => "Alice" }) }.to raise_error(
          EvalEngine::Types::ValidationError,
          /age: Missing required field/
        )
      end

      it "reports all missing fields in the error message" do
        expect { type.validate!({}) }.to raise_error(EvalEngine::Types::ValidationError) do |err|
          expect(err.message).to include("name: Missing required field")
          expect(err.message).to include("age: Missing required field")
        end
      end

      it "treats string and symbol keys as equivalent for presence" do
        expect { type.validate!({ "name" => "Alice", "age" => 30 }) }.not_to raise_error
        expect { type.validate!({ name: "Alice", age: 30 }) }.not_to raise_error
      end
    end

    context "tree-shaped validation errors" do
      subject(:type) do
        described_class.new(
          fields: {
            name: EvalEngine::Types::StringType.new,
            age: EvalEngine::Types::IntegerType.new
          }
        )
      end

      it "returns nil when the value is valid" do
        expect(type.validate({ name: "Alice", age: 30 })).to be_nil
      end

      it "returns a children tree pinpointing each failing field" do
        tree = type.validate({ name: 123, age: "x" })

        expect(tree).to eq(
          "children" => {
            "name" => {
              "errors" => ["Expected string, got Integer"]
            },
            "age" => {
              "errors" => ["Expected integer, got String"]
            }
          }
        )
      end

      it "exposes the tree on the raised ValidationError" do
        expect { type.validate!({ name: 123, age: 30 }) }.to raise_error(EvalEngine::Types::ValidationError) do |err|
          expect(err.tree).to eq("children" => { "name" => { "errors" => ["Expected string, got Integer"] } })
        end
      end
    end
  end

  describe EvalEngine::Types::ArrayType do
    context "ordered" do
      subject(:type) { described_class.new(element_type: EvalEngine::Types::StringType.new, order: :ordered) }

      it "returns 1.0 for equal arrays" do
        result = type.match(%w[a b c], %w[a b c])
        expect(result["score"]).to eq(1.0)
      end

      it "averages 1.0 + 0.25 (string-mismatch floor) + 1.0 when one element differs" do
        result = type.match(%w[a x c], %w[a b c])
        expect(result["score"]).to be_within(0.001).of(2.25 / 3.0)
      end

      it "scores 0.0 for missing elements when actual is shorter" do
        # Index 0 matches (1.0), indexes 1 and 2 are missing-from-actual: nil-vs-string → 0.0 each.
        result = type.match(["a"], %w[a b c])
        expect(result["score"]).to be_within(0.001).of(1.0 / 3.0)
        expect(result["children"].length).to eq(3)
      end

      it "scores 0.0 for extra elements when actual is longer" do
        # Index 0 matches, indexes 1 and 2 are string-vs-nil → 0.0 each.
        result = type.match(%w[a b c], ["a"])
        expect(result["score"]).to be_within(0.001).of(1.0 / 3.0)
      end

      it "returns 1.0 for two empty arrays" do
        result = type.match([], [])
        expect(result["score"]).to eq(1.0)
      end

      it "includes children with per-element scores" do
        result = type.match(%w[a b], %w[a b])
        expect(result["children"]).to eq([{ "score" => 1.0 }, { "score" => 1.0 }])
      end
    end

    context "unordered with key: :itself" do
      subject(:type) do
        described_class.new(element_type: EvalEngine::Types::StringType.new, order: :unordered, key: :itself)
      end

      it "returns 1.0 for same elements in different order" do
        result = type.match(%w[b a c], %w[a b c])
        expect(result["score"]).to eq(1.0)
      end

      it "scores 0.0 for a missing expected element" do
        result = type.match(%w[a c], %w[a b c])
        expect(result["score"]).to be_within(0.01).of(2.0 / 3.0)
      end

      it "scores 0.0 for an extra actual element" do
        result = type.match(%w[a b c d], %w[a b c])
        children = result["children"]
        expect(children.length).to eq(4)
        expect(children.last).to eq("score" => 0.0)
      end

      it "includes alignment entries for extra actual elements" do
        result = type.match(%w[a b c d], %w[a b c])
        alignment = result["alignment"]
        extra_entry = alignment.find { |a| a["expected"].nil? }
        expect(extra_entry).not_to be_nil
        expect(extra_entry["actual"]).to eq(3)
      end

      it "includes alignment array showing expected-to-actual mapping" do
        result = type.match(%w[b a], %w[a b])
        alignment = result["alignment"]
        expect(alignment).to contain_exactly({ "expected" => 0, "actual" => 1 }, { "expected" => 1, "actual" => 0 })
      end
    end

    context "unordered with key: :name (hash elements)" do
      let(:element_type) do
        EvalEngine::Types::HashType.new(
          fields: {
            name: EvalEngine::Types::StringType.new,
            value: EvalEngine::Types::IntegerType.new
          }
        )
      end

      subject(:type) { described_class.new(element_type: element_type, order: :unordered, key: :name) }

      it "matches by string key access on name" do
        actual = [{ "name" => "b", "value" => 2 }, { "name" => "a", "value" => 1 }]
        expected = [{ "name" => "a", "value" => 1 }, { "name" => "b", "value" => 2 }]
        result = type.match(actual, expected)
        expect(result["score"]).to eq(1.0)
      end

      it "scores 0.0 for unmatched keys" do
        actual = [{ "name" => "a", "value" => 1 }]
        expected = [{ "name" => "a", "value" => 1 }, { "name" => "b", "value" => 2 }]
        result = type.match(actual, expected)
        expect(result["score"]).to eq(0.5)
      end
    end

    context "duplicate key error" do
      subject(:type) do
        described_class.new(element_type: EvalEngine::Types::StringType.new, order: :unordered, key: :itself)
      end

      it "raises DuplicateKeyError when actual has duplicate keys" do
        expect { type.match(%w[a a], %w[a b]) }.to raise_error(EvalEngine::Types::DuplicateKeyError, /Duplicate key/)
      end
    end

    context "validation" do
      subject(:type) { described_class.new(element_type: EvalEngine::Types::IntegerType.new, order: :ordered) }

      it "accepts arrays of the element type" do
        expect { type.validate!([1, 2, 3]) }.not_to raise_error
      end

      it "accepts nil" do
        expect { type.validate!(nil) }.not_to raise_error
      end

      it "rejects non-arrays" do
        expect { type.validate!("not an array") }.to raise_error(EvalEngine::Types::ValidationError, /Expected array/)
      end

      it "rejects elements of the wrong type with index in message" do
        expect { type.validate!([1, "bad", 3]) }.to raise_error(
          EvalEngine::Types::ValidationError,
          /\[1\]: Expected integer/
        )
      end
    end

    context "unordered without key option" do
      it "raises ArgumentError" do
        expect {
          described_class.new(element_type: EvalEngine::Types::StringType.new, order: :unordered)
        }.to raise_error(ArgumentError, /key/)
      end
    end
  end

  describe EvalEngine::Types::CustomType do
    it "delegates to the matcher object" do
      matcher = instance_double("Matcher")
      allow(matcher).to receive(:match).with("a", "b").and_return("score" => 0.42)

      type = described_class.new(matcher: matcher)
      result = type.match("a", "b")

      expect(result).to eq("score" => 0.42)
      expect(matcher).to have_received(:match).with("a", "b")
    end

    it "passes validation for any value" do
      type = described_class.new(matcher: double("Matcher"))
      expect { type.validate!("anything") }.not_to raise_error
      expect { type.validate!(nil) }.not_to raise_error
      expect { type.validate!(123) }.not_to raise_error
    end
  end

  describe EvalEngine::Types::HashTypeBuilder do
    it "builds a HashType with a StringType field" do
      builder = described_class.new
      builder.field(:name, :string)
      hash_type = builder.build

      expect(hash_type).to be_a(EvalEngine::Types::HashType)
      result = hash_type.match({ name: "Alice" }, { name: "Alice" })
      expect(result["score"]).to eq(1.0)
    end

    it "builds with an ArrayType field using of: option" do
      builder = described_class.new
      builder.field(:tags, :array, of: :string, order: :ordered)
      hash_type = builder.build

      result = hash_type.match({ tags: %w[ruby rails] }, { tags: %w[ruby rails] })
      expect(result["score"]).to eq(1.0)
    end

    it "builds nested hash fields with a block" do
      builder = described_class.new
      builder.field(:address, :hash) do
        field(:street, :string)
        field(:zip, :string)
      end
      hash_type = builder.build

      result =
        hash_type.match(
          { address: { street: "123 Main", zip: "90210" } },
          { address: { street: "123 Main", zip: "90210" } }
        )
      expect(result["score"]).to eq(1.0)
    end

    it "passes weight option through to the built type" do
      builder = described_class.new
      builder.field(:name, :string, weight: 3)
      builder.field(:age, :integer, weight: 1)
      hash_type = builder.build

      # name matches (1.0, weight 3); age floors to 0.25 (weight 1) → (3.0 + 0.25) / 4 = 0.8125
      result = hash_type.match({ name: "Alice", age: 99 }, { name: "Alice", age: 30 })
      expect(result["score"]).to eq(0.8125)
    end

    it "builds correctly with multiple field types" do
      builder = described_class.new
      builder.field(:name, :string)
      builder.field(:age, :integer)
      builder.field(:active, :boolean)
      hash_type = builder.build

      result = hash_type.match({ name: "Alice", age: 30, active: true }, { name: "Alice", age: 30, active: true })
      expect(result["score"]).to eq(1.0)
    end
  end

  describe ".build" do
    it "builds a StringType for :string" do
      expect(described_class.build(:string)).to be_a(EvalEngine::Types::StringType)
    end

    it "builds an IntegerType for :integer" do
      expect(described_class.build(:integer)).to be_a(EvalEngine::Types::IntegerType)
    end

    it "builds a FloatType for :float" do
      expect(described_class.build(:float)).to be_a(EvalEngine::Types::FloatType)
    end

    it "builds a BooleanType for :boolean" do
      expect(described_class.build(:boolean)).to be_a(EvalEngine::Types::BooleanType)
    end

    it "builds a HashType for :hash without a block" do
      expect(described_class.build(:hash)).to be_a(EvalEngine::Types::HashType)
    end

    it "builds a HashType with fields for :hash with a block" do
      type = described_class.build(:hash) { field :name, :string }
      expect(type).to be_a(EvalEngine::Types::HashType)
      expect(type.fields).to have_key(:name)
    end

    it "builds an ArrayType for :array with of: option" do
      expect(described_class.build(:array, of: :string)).to be_a(EvalEngine::Types::ArrayType)
    end

    it "builds a CustomType for :custom with matcher:" do
      matcher = double("Matcher")
      expect(described_class.build(:custom, matcher: matcher)).to be_a(EvalEngine::Types::CustomType)
    end

    it "raises ArgumentError for unknown types" do
      expect { described_class.build(:unknown) }.to raise_error(ArgumentError, /Unknown type/)
    end

    it "raises ArgumentError for :array without of:" do
      expect { described_class.build(:array) }.to raise_error(ArgumentError, /requires/)
    end

    it "passes options through to the built type" do
      type = described_class.build(:integer, tolerance: 5)
      result = type.match(43, 45)
      expect(result["score"]).to eq(1.0)
    end
  end
end
