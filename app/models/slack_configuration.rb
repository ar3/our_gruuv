class SlackConfiguration < ApplicationRecord
  belongs_to :organization
  
  # Validations
  validates :workspace_id, presence: true, uniqueness: true
  validates :workspace_name, presence: true
  validates :bot_token, presence: true, uniqueness: true
  validates :installed_at, presence: true
  
  # Scopes
  scope :active, -> { where.not(bot_token: nil) }
  
  # Instance methods
  def configured?
    bot_token.present? && workspace_id.present?
  end
  
  def workspace_url
    self[:workspace_url].presence || "https://#{workspace_name}.slack.com"
  end
  
  def display_name
    "#{workspace_name} (#{workspace_id})"
  end
  
  def default_channel_or_general
    default_channel.presence || '#bot-test'
  end
  
  def bot_username_or_default
    bot_username.presence || 'OG'
  end
  
  def bot_emoji_or_default
    bot_emoji.presence || ':sparkles:'
  end
  
  # TODO: Add encryption for bot_token when Active Record encryption is configured
  # encrypts :bot_token
end
