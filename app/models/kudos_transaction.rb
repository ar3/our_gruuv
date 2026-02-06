class KudosTransaction < ApplicationRecord
  self.inheritance_column = 'type'

  belongs_to :company_teammate
  belongs_to :organization
  belongs_to :observation, optional: true
  belongs_to :observable_moment, optional: true
  belongs_to :kudos_redemption, optional: true
  belongs_to :company_teammate_banker, class_name: 'CompanyTeammate', optional: true
  belongs_to :triggering_transaction, class_name: 'KudosTransaction', optional: true

  has_many :triggered_transactions, class_name: 'KudosTransaction', foreign_key: :triggering_transaction_id

  validates :company_teammate, :organization, presence: true
  validate :deltas_in_half_increments

  scope :by_teammate, ->(teammate) { where(company_teammate: teammate) }
  scope :for_organization, ->(org) { where(organization: org) }
  scope :recent, -> { order(created_at: :desc) }

  def apply_to_ledger!
    ledger = KudosPointsLedger.find_or_create_for(company_teammate, organization)

    ApplicationRecord.transaction do
      if points_to_give_delta.present? && points_to_give_delta != 0
        if points_to_give_delta > 0
          ledger.add_to_give(points_to_give_delta)
        else
          ledger.deduct_from_give(points_to_give_delta.abs)
        end
      end

      if points_to_spend_delta.present? && points_to_spend_delta != 0
        if points_to_spend_delta > 0
          ledger.add_to_spend(points_to_spend_delta)
        else
          ledger.deduct_from_spend(points_to_spend_delta.abs)
        end
      end
    end
  end

  def related_person
    observation&.observer
  end

  def net_points_change
    (points_to_give_delta || 0) + (points_to_spend_delta || 0)
  end

  def transaction_type_display
    type&.demodulize&.titleize&.gsub(' Transaction', '') || 'Transaction'
  end

  private

  def deltas_in_half_increments
    if points_to_give_delta.present? && (points_to_give_delta * 2) % 1 != 0
      errors.add(:points_to_give_delta, 'must be in 0.5 increments')
    end
    if points_to_spend_delta.present? && (points_to_spend_delta * 2) % 1 != 0
      errors.add(:points_to_spend_delta, 'must be in 0.5 increments')
    end
  end
end
