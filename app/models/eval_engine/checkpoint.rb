module EvalEngine
  class Checkpoint < Record
    validates :eval_name, presence: true, uniqueness: true
    validates :checkpointed_at, presence: true
  end
end
