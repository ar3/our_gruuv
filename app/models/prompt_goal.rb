class PromptGoal < ApplicationRecord
  # Associations
  belongs_to :prompt
  belongs_to :goal

  # Validations
  validates :prompt, presence: true
  validates :goal, presence: true
  validates :goal_id, uniqueness: { scope: :prompt_id }
end


