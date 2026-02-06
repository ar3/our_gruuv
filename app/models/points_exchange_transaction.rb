# STI subclass of KudosTransaction
# Used for observation-based point transfers (recognition/constructive feedback)
# Points go TO the observee (recipient) as recognition/constructive feedback
class PointsExchangeTransaction < KudosTransaction
  # Points exchange must be linked to an observation
  validates :observation_id, presence: true

  # Should have points to spend (what the recipient receives)
  validate :has_points_to_spend

  # Scopes
  scope :for_observation, ->(observation) { where(observation: observation) }
  scope :from_company_bank, -> { joins(:observation).where.not(observations: { observable_moment_id: nil }) }
  scope :from_observer_balance, -> { joins(:observation).where(observations: { observable_moment_id: nil }) }

  def recipient
    company_teammate
  end

  def recipient_name
    company_teammate&.person&.display_name || "Unknown"
  end

  def observer
    observation&.observer
  end

  def observer_name
    observer&.display_name || "Unknown"
  end

  # Points came from company bank if observation was tied to an observable moment
  def from_company_bank?
    observation&.observable_moment_id.present?
  end

  # Points came from observer's balance
  def from_observer_balance?
    !from_company_bank?
  end

  def feedback_type
    observation&.has_negative_ratings? ? :constructive : :recognition
  end

  def recognition?
    feedback_type == :recognition
  end

  def constructive?
    feedback_type == :constructive
  end

  private

  def has_points_to_spend
    spend = points_to_spend_delta.to_f

    if spend <= 0
      errors.add(:points_to_spend_delta, "must be positive for point exchange")
    end
  end
end
