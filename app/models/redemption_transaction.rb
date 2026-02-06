# STI subclass of KudosTransaction
# Used for reward redemptions (spending points)
# Points are deducted from points_to_spend balance
class RedemptionTransaction < KudosTransaction
  belongs_to :kudos_redemption, foreign_key: :kudos_redemption_id

  # Redemption must be linked to a redemption record
  validates :kudos_redemption_id, presence: true

  # Must have negative points_to_spend_delta (spending points)
  validate :has_negative_spend_delta

  # Scopes
  scope :for_redemption, ->(redemption) { where(kudos_redemption: redemption) }

  # Helpers
  def redeemer
    company_teammate
  end

  def redeemer_name
    company_teammate&.person&.display_name || "Unknown"
  end

  def redemption
    kudos_redemption
  end

  def reward
    kudos_redemption&.kudos_reward
  end

  def reward_name
    reward&.name || "Unknown Reward"
  end

  def points_spent
    points_to_spend_delta.abs
  end

  def points_spent_in_dollars
    points_spent / 10.0
  end

  def transaction_summary
    "Redeemed #{points_spent} points for #{reward_name}"
  end

  private

  def has_negative_spend_delta
    spend = points_to_spend_delta.to_f

    if spend >= 0
      errors.add(:points_to_spend_delta, "must be negative for redemptions (spending points)")
    end
  end
end
