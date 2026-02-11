# Represents a redemption of kudos points for a reward
# Tracks the status of fulfillment (pending -> processing -> fulfilled/failed)
class KudosRedemption < ApplicationRecord
  belongs_to :company_teammate
  belongs_to :organization
  belongs_to :kudos_reward
  has_one :redemption_transaction, class_name: 'RedemptionTransaction',
          foreign_key: :kudos_redemption_id, dependent: :restrict_with_error

  # Status values
  STATUSES = %w[pending processing fulfilled failed cancelled].freeze

  validates :points_spent, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :reward_belongs_to_organization
  validate :teammate_belongs_to_organization

  # Scopes
  scope :for_teammate, ->(teammate) { where(company_teammate: teammate) }
  scope :for_organization, ->(org) { where(organization: org) }
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :fulfilled, -> { where(status: 'fulfilled') }
  scope :failed, -> { where(status: 'failed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :active, -> { where(status: %w[pending processing]) }
  scope :completed, -> { where(status: %w[fulfilled failed cancelled]) }
  scope :recent, -> { order(created_at: :desc) }

  # State machine-like methods
  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def fulfilled?
    status == 'fulfilled'
  end

  def failed?
    status == 'failed'
  end

  def cancelled?
    status == 'cancelled'
  end

  def can_cancel?
    pending? || processing?
  end

  def can_fulfill?
    pending? || processing?
  end

  def mark_processing!
    raise InvalidStateTransition, "Cannot process from #{status}" unless pending?

    update!(status: 'processing')
  end

  def mark_fulfilled!(external_ref: nil)
    raise InvalidStateTransition, "Cannot fulfill from #{status}" unless can_fulfill?

    update!(
      status: 'fulfilled',
      fulfilled_at: Time.current,
      external_reference: external_ref
    )
  end

  def mark_failed!(reason: nil)
    raise InvalidStateTransition, "Cannot fail from #{status}" unless can_fulfill?

    update!(
      status: 'failed',
      notes: [notes, "Failed: #{reason}"].compact.join("\n")
    )
  end

  def mark_cancelled!(reason: nil)
    raise InvalidStateTransition, "Cannot cancel from #{status}" unless can_cancel?

    update!(
      status: 'cancelled',
      notes: [notes, "Cancelled: #{reason}"].compact.join("\n")
    )
  end

  # Helpers
  def redeemer
    company_teammate
  end

  def redeemer_name
    company_teammate&.person&.display_name || "Unknown"
  end

  def reward
    kudos_reward
  end

  def reward_name
    kudos_reward&.name || "Unknown Reward"
  end

  def points_spent_in_dollars
    points_spent / 10.0
  end

  class InvalidStateTransition < StandardError; end

  private

  def reward_belongs_to_organization
    return unless kudos_reward && organization

    unless kudos_reward.organization_id == organization_id
      errors.add(:kudos_reward, 'must belong to the same organization')
    end
  end

  def teammate_belongs_to_organization
    return unless company_teammate && organization

    unless company_teammate.organization_id == organization_id
      errors.add(:company_teammate, 'must belong to the same organization')
    end
  end
end
