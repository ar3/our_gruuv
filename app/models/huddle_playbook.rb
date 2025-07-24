class HuddlePlaybook < ApplicationRecord
  belongs_to :organization
  has_many :huddles, dependent: :nullify
  
  validates :instruction_alias, presence: true, uniqueness: { scope: :organization_id }
  validates :slack_channel, format: { with: /\A#[a-zA-Z0-9_-]+\z/, message: "must be a valid Slack channel (e.g., #general)" }, allow_blank: true
  
  def display_name
    instruction_alias.present? ? instruction_alias.titleize : "Unnamed Playbook"
  end
  
  def slack_channel_or_organization_default
    slack_channel.presence || organization.slack_configuration&.default_channel_or_general || "#general"
  end
end
