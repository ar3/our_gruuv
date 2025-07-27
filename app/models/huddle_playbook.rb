class HuddlePlaybook < ApplicationRecord
  belongs_to :organization
  has_many :huddles, dependent: :nullify
  
  validates :special_session_name, uniqueness: { scope: :organization_id }, allow_blank: true
  validates :slack_channel, format: { with: /\A#[a-zA-Z0-9_-]+\z/, message: "must be a valid Slack channel (e.g., #general)" }, allow_blank: true
  
  def display_name
    special_session_name.present? ? special_session_name.titleize : "Base Team Playbook"
  end
  
  def slack_configuration
    organization.calculated_slack_config
  end

  def slack_channel_or_organization_default
    slack_channel.presence || slack_configuration&.default_channel_or_general || "#bot-test"
  end

end
