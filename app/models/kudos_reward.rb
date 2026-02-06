# Represents a reward item that can be redeemed with kudos points
# Examples: gift cards, company swag, experiences, etc.
class KudosReward < ApplicationRecord
  belongs_to :organization
  has_many :kudos_redemptions, dependent: :restrict_with_error

  # Reward types
  REWARD_TYPES = %w[gift_card merchandise experience donation custom].freeze

  validates :name, presence: true
  validates :cost_in_points, presence: true, numericality: { greater_than: 0 }
  validates :reward_type, presence: true, inclusion: { in: REWARD_TYPES }
  validate :cost_in_half_increments

  # Scopes
  scope :active, -> { where(active: true, deleted_at: nil) }
  scope :inactive, -> { where(active: false).or(where.not(deleted_at: nil)) }
  scope :for_organization, ->(org) { where(organization: org) }
  scope :by_type, ->(type) { where(reward_type: type) }
  scope :by_cost, -> { order(cost_in_points: :asc) }
  scope :affordable_with, ->(points) { where('cost_in_points <= ?', points) }

  # Soft delete support
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def available?
    active? && !deleted?
  end

  # Dollar value helpers (10 points = $1)
  def cost_in_dollars
    cost_in_points / 10.0
  end

  # Type helpers
  def gift_card?
    reward_type == 'gift_card'
  end

  def merchandise?
    reward_type == 'merchandise'
  end

  def experience?
    reward_type == 'experience'
  end

  def donation?
    reward_type == 'donation'
  end

  def custom?
    reward_type == 'custom'
  end

  # Metadata helpers
  def provider
    metadata['provider']
  end

  def provider=(value)
    self.metadata = metadata.merge('provider' => value)
  end

  def external_id
    metadata['external_id']
  end

  def external_id=(value)
    self.metadata = metadata.merge('external_id' => value)
  end

  # Display helpers
  def display_name
    name
  end

  def display_cost
    "#{cost_in_points.to_i} points" + (cost_in_points % 1 != 0 ? " (#{cost_in_points} points)" : "")
  end

  private

  def cost_in_half_increments
    return unless cost_in_points.present?

    if (cost_in_points * 2) % 1 != 0
      errors.add(:cost_in_points, 'must be in 0.5 increments')
    end
  end
end
