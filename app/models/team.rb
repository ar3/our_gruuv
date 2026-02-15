class Team < ApplicationRecord
  # Associations
  belongs_to :company, class_name: 'Organization'
  has_many :team_members, dependent: :destroy
  has_many :company_teammates, through: :team_members
  has_many :people, through: :company_teammates, source: :person
  has_many :huddles, dependent: :destroy
  has_many :third_party_object_associations, as: :associatable, dependent: :destroy
  has_one :team_asana_link, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :company, presence: true

  # Soft delete support
  scope :active, -> { where(deleted_at: nil) }
  scope :archived, -> { where.not(deleted_at: nil) }

  # Convenience scopes
  scope :ordered, -> { order(:name) }
  scope :for_company, ->(company) { where(company: company) }

  # Instance methods
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def archived?
    deleted_at.present?
  end

  def active?
    deleted_at.nil?
  end

  def display_name
    name
  end

  # For URL generation (friendly URLs)
  def to_param
    "#{id}-#{name.parameterize}" if persisted?
  end

  # Huddle channel association methods (similar to kudos_channel on Organization)
  def huddle_channel_association
    third_party_object_associations.find_by(association_type: 'huddle_channel')
  end

  def huddle_channel
    huddle_channel_association&.third_party_object
  end

  def huddle_channel_id
    huddle_channel&.third_party_id
  end

  def huddle_channel_id=(channel_id)
    if channel_id.present?
      # Use company's third_party_objects since teams don't have their own
      channel = company.third_party_objects.slack_channels.find_by(third_party_id: channel_id)
      if channel
        # Remove existing association
        huddle_channel_association&.destroy

        # Create new association
        third_party_object_associations.create!(
          third_party_object: channel,
          association_type: 'huddle_channel'
        )
      end
    else
      huddle_channel_association&.destroy
    end
  end

  def slack_configuration
    company&.calculated_slack_config
  end

  def huddle_slack_configured?
    huddle_channel_id.present? && slack_configuration&.configured?
  end
end
