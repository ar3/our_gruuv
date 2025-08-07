class ThirdPartyObject < ApplicationRecord
  # Associations
  belongs_to :organization
  has_many :third_party_object_associations, dependent: :destroy
  has_many :associatables, through: :third_party_object_associations, source: :associatable, source_type: 'Organization'

  # Validations
  validates :display_name, presence: true
  validates :third_party_name, presence: true
  validates :third_party_id, presence: true, uniqueness: { scope: [:organization_id, :third_party_source] }
  validates :third_party_object_type, presence: true
  validates :third_party_source, presence: true

  # Scopes
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  scope :slack_channels, -> { where(third_party_source: 'slack', third_party_object_type: 'channel') }
  scope :for_organization, ->(org) { where(organization: org) }

  # Instance methods
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def deleted?
    deleted_at.present?
  end

  def slack_channel?
    third_party_source == 'slack' && third_party_object_type == 'channel'
  end
end 