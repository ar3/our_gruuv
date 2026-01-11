class Aspiration < ApplicationRecord
  include ModelSemanticVersionable

  belongs_to :organization
  has_many :observation_ratings, as: :rateable, dependent: :destroy
  has_many :observations, through: :observation_ratings
  has_many :comments, as: :commentable, dependent: :destroy

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

  # Finder method that handles both id and id-name formats
  def self.find_by_param(param)
    # If param is just a number, use it as id
    return find(param) if param.to_s.match?(/\A\d+\z/)
    
    # Otherwise, extract id from id-name format
    id = param.to_s.split('-').first
    find(id)
  end

  def to_param
    "#{id}-#{name.parameterize}"
  end
end
