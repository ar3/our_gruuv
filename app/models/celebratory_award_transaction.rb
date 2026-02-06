# STI subclass of KudosTransaction
# Used for automatic point awards triggered by observable moments (company bank awards)
# These are system-generated and don't require a banker
class CelebratoryAwardTransaction < KudosTransaction
  # Celebratory awards must be associated with an observable moment
  validates :observable_moment_id, presence: true

  # Should have at least one positive delta
  validate :has_positive_award

  # Scopes
  scope :for_moment_type, ->(type) { joins(:observable_moment).where(observable_moments: { moment_type: type }) }
  scope :for_recipient, ->(teammate) { where(company_teammate: teammate) }

  def recipient
    company_teammate
  end

  def recipient_name
    company_teammate&.person&.display_name || "Unknown"
  end

  def moment_type
    observable_moment&.moment_type
  end

  def moment_display_name
    observable_moment&.display_name || "Celebratory Award"
  end

  def award_summary
    parts = []
    parts << "#{points_to_give_delta} points to give" if points_to_give_delta.to_f > 0
    parts << "#{points_to_spend_delta} points to spend" if points_to_spend_delta.to_f > 0
    parts.join(" and ")
  end

  def reason
    "Celebratory award for: #{moment_display_name}"
  end

  private

  def has_positive_award
    give = points_to_give_delta.to_f
    spend = points_to_spend_delta.to_f

    if give <= 0 && spend <= 0
      errors.add(:base, "Must award at least some points (to give or to spend)")
    end

    if give < 0
      errors.add(:points_to_give_delta, "cannot be negative for celebratory awards")
    end

    if spend < 0
      errors.add(:points_to_spend_delta, "cannot be negative for celebratory awards")
    end
  end
end
