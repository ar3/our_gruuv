class HuddleInstruction < ApplicationRecord
  belongs_to :organization
  has_many :huddles, dependent: :nullify
  
  # Validations
  validates :organization, presence: true
  validates :instruction_alias, uniqueness: { scope: :organization_id, allow_blank: true }
  
  # Instance methods
  def display_name
    if instruction_alias.present?
      instruction_alias.humanize
    else
      "Unnamed Huddle"
    end
  end
  
  def default_slack_channel
    slack_channel.presence || "##{display_name.parameterize}_huddles"
  end
  
  def slack_channel_or_organization_default
    slack_channel.presence || organization&.slack_config&.default_channel_or_general
  end
end
