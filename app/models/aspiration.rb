class Aspiration < ApplicationRecord
  belongs_to :organization
  has_many :observation_ratings, as: :rateable, dependent: :destroy
  has_many :observations, through: :observation_ratings

  validates :name, presence: true, uniqueness: { scope: :organization_id }
  validates :sort_order, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Soft delete implementation following existing pattern
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  # Scope for ordering by sort_order
  scope :ordered, -> { order(:sort_order, :name) }

  # Scope for finding aspirations within organization hierarchy
  scope :within_hierarchy, ->(organization) {
    where(organization: organization.self_and_descendants)
  }
end
