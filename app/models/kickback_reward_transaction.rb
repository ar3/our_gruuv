# STI subclass of KudosTransaction
# Used for earned rewards from giving feedback (observer kickback)
# Points go TO the observer as a reward for giving feedback
class KickbackRewardTransaction < KudosTransaction
  # Kickback must be linked to an observation
  validates :observation_id, presence: true

  # Should have at least one positive delta
  validate :has_positive_reward

  # Scopes
  scope :for_observation, ->(observation) { where(observation: observation) }

  def observer
    company_teammate&.person
  end

  def observer_name
    company_teammate&.person&.display_name || "Unknown"
  end

  def observation_story
    observation&.story
  end

  def feedback_type
    observation&.has_negative_ratings? ? :constructive : :recognition
  end

  def recognition_kickback?
    feedback_type == :recognition
  end

  def constructive_kickback?
    feedback_type == :constructive
  end

  def reward_summary
    parts = []
    parts << "#{points_to_give_delta} points to give" if points_to_give_delta.to_f > 0
    parts << "#{points_to_spend_delta} points to spend" if points_to_spend_delta.to_f > 0
    parts.join(" and ")
  end

  private

  def has_positive_reward
    give = points_to_give_delta.to_f
    spend = points_to_spend_delta.to_f

    if give <= 0 && spend <= 0
      errors.add(:base, "Must have at least some reward points")
    end

    if give < 0
      errors.add(:points_to_give_delta, "cannot be negative for kickback rewards")
    end

    if spend < 0
      errors.add(:points_to_spend_delta, "cannot be negative for kickback rewards")
    end
  end
end
