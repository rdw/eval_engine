require "rails_helper"

RSpec.describe EvalEngine::Checkpoint, type: :model do
  describe "persistence" do
    it "saves with eval_name and checkpointed_at" do
      checkpoint = described_class.create!(eval_name: "is_ebike_manufacturer", checkpointed_at: Time.current)

      expect(checkpoint).to have_attributes(eval_name: "is_ebike_manufacturer")
      expect(checkpoint).to be_persisted
    end
  end

  describe "validations" do
    it "requires eval_name" do
      checkpoint = described_class.new(checkpointed_at: Time.current)
      expect(checkpoint).not_to be_valid
      expect(checkpoint.errors[:eval_name]).to be_present
    end

    it "requires checkpointed_at" do
      checkpoint = described_class.new(eval_name: "x")
      expect(checkpoint).not_to be_valid
      expect(checkpoint.errors[:checkpointed_at]).to be_present
    end

    context "with an existing checkpoint for the same eval_name" do
      let!(:existing) { described_class.create!(eval_name: "foo", checkpointed_at: Time.current) }

      it "rejects a second checkpoint with the same eval_name" do
        expect { described_class.create!(eval_name: "foo", checkpointed_at: Time.current) }.to raise_error(
          ActiveRecord::RecordInvalid,
          /eval name has already been taken/i
        )
      end

      it "permits a different eval_name" do
        expect { described_class.create!(eval_name: "bar", checkpointed_at: Time.current) }.not_to raise_error
      end
    end
  end
end
