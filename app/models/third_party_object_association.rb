class ThirdPartyObjectAssociation < ApplicationRecord
  # Associations
  belongs_to :third_party_object
  belongs_to :associatable, polymorphic: true

  # Validations
  validates :association_type, presence: true
  validates :associatable_id, uniqueness: { scope: [:associatable_type, :association_type] }

  # Scopes
  scope :huddle_review_notification_channels, -> { where(association_type: 'huddle_review_notification_channel') }
end 