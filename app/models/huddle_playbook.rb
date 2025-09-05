class HuddlePlaybook < ApplicationRecord
  belongs_to :organization
  has_many :huddles, dependent: :nullify
  
  validates :slack_channel, format: { with: /\A#[a-zA-Z0-9_-]+\z/, message: "must be a valid Slack channel (e.g., #general)" }, allow_blank: true
  
  before_validation :normalize_special_session_name
  
  def display_name
    display_special_session_name
  end

  def display_special_session_name
    special_session_name.present? ? special_session_name.titleize : "Base Team Playbook"
  end
  
  def slack_configuration
    organization.calculated_slack_config
  end

  def slack_channel_or_organization_default
    slack_channel.presence || slack_configuration&.default_channel_or_general || "#bot-test"
  end

  private

  def normalize_special_session_name
    # Convert nil and whitespace-only strings to empty string for consistency
    # This ensures database-level uniqueness constraint works properly
    self.special_session_name = '' if special_session_name.blank?
  end
end
