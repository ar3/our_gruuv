class KudosPointsLedger < ApplicationRecord
  belongs_to :company_teammate
  belongs_to :organization

  validates :company_teammate_id, uniqueness: { scope: :organization_id }
  validates :points_to_give, :points_to_spend, numericality: { greater_than_or_equal_to: 0 }
  validate :points_in_half_increments

  scope :for_organization, ->(org) { where(organization: org) }
  scope :with_balance, -> { where('points_to_give > 0 OR points_to_spend > 0') }

  class InsufficientBalance < StandardError; end

  def self.find_or_create_for(company_teammate, organization)
    find_or_create_by!(company_teammate: company_teammate, organization: organization)
  end

  def add_to_give(amount)
    increment!(:points_to_give, amount)
  end

  def add_to_spend(amount)
    increment!(:points_to_spend, amount)
  end

  def deduct_from_give(amount)
    raise InsufficientBalance, "Insufficient points to give" unless can_give?(amount)
    decrement!(:points_to_give, amount)
  end

  def deduct_from_spend(amount)
    raise InsufficientBalance, "Insufficient points to spend" if points_to_spend < amount
    decrement!(:points_to_spend, amount)
  end

  def can_give?(amount)
    points_to_give >= amount
  end

  def can_spend?(amount)
    points_to_spend >= amount
  end

  def recalculate_balance!
    transactions = KudosTransaction.where(company_teammate: company_teammate, organization: organization)
    update!(
      points_to_give: [transactions.sum(:points_to_give_delta), 0].max,
      points_to_spend: [transactions.sum(:points_to_spend_delta), 0].max
    )
  end

  # Dollar value helpers
  def points_to_give_dollar_value
    points_to_give / 10.0
  end

  def points_to_spend_dollar_value
    points_to_spend / 10.0
  end

  def total_dollar_value
    (points_to_give + points_to_spend) / 10.0
  end

  private

  def points_in_half_increments
    if points_to_give.present? && (points_to_give * 2) % 1 != 0
      errors.add(:points_to_give, 'must be in 0.5 increments')
    end
    if points_to_spend.present? && (points_to_spend * 2) % 1 != 0
      errors.add(:points_to_spend, 'must be in 0.5 increments')
    end
  end
end
