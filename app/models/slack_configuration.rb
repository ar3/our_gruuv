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
    "https://#{workspace_name}.slack.com"
  end
  
  def display_name
    "#{workspace_name} (#{workspace_id})"
  end
  
  # TODO: Add encryption for bot_token when Active Record encryption is configured
  # encrypts :bot_token
end
