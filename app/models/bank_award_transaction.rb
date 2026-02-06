# STI subclass of KudosTransaction
# Used for manual point awards by kudos bankers (admins with can_manage_kudos_rewards)
class BankAwardTransaction < KudosTransaction
  # Bank awards require a banker and a reason
  validates :company_teammate_banker_id, presence: true
  validates :reason, presence: true

  # Bank awards should have at least one positive delta
  validate :has_positive_award

  # Banker must have kudos management permission
  validate :banker_has_permission

  # Alias for easier access to the banker association
  def banker
    company_teammate_banker
  end

  def banker=(value)
    self.company_teammate_banker = value
  end

  # Scopes
  scope :by_banker, ->(banker) { where(company_teammate_banker: banker) }
  scope :awarded_to, ->(recipient) { where(company_teammate: recipient) }

  def recipient
    company_teammate
  end

  def recipient_name
    company_teammate&.person&.display_name || "Unknown"
  end

  def banker_name
    company_teammate_banker&.person&.display_name || "Unknown"
  end

  def award_summary
    parts = []
    parts << "#{points_to_give_delta} points to give" if points_to_give_delta.to_f > 0
    parts << "#{points_to_spend_delta} points to spend" if points_to_spend_delta.to_f > 0
    parts.join(" and ")
  end

  private

  def has_positive_award
    give = points_to_give_delta.to_f
    spend = points_to_spend_delta.to_f

    if give <= 0 && spend <= 0
      errors.add(:base, "Must award at least some points (to give or to spend)")
    end

    if give < 0
      errors.add(:points_to_give_delta, "cannot be negative for bank awards")
    end

    if spend < 0
      errors.add(:points_to_spend_delta, "cannot be negative for bank awards")
    end
  end

  def banker_has_permission
    return unless company_teammate_banker.present?

    unless company_teammate_banker.can_manage_kudos_rewards?
      errors.add(:company_teammate_banker, "does not have permission to award points")
    end
  end
end
