class TeammateIdentity < ApplicationRecord
  belongs_to :teammate
  
  # Validations
  validates :provider, presence: true
  validates :uid, presence: true
  validates :uid, uniqueness: { scope: :provider }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  
  # Scopes
  scope :slack, -> { where(provider: 'slack') }
  scope :jira, -> { where(provider: 'jira') }
  scope :linear, -> { where(provider: 'linear') }
  scope :asana, -> { where(provider: 'asana') }
  
  # Instance methods
  def slack?
    provider == 'slack'
  end
  
  def jira?
    provider == 'jira'
  end
  
  def linear?
    provider == 'linear'
  end
  
  def asana?
    provider == 'asana'
  end
  
  def display_name
    provider_name = provider&.titleize || 'Unknown'
    if name.present?
      "#{provider_name} (#{name} - #{email})"
    else
      "#{provider_name} (#{email})"
    end
  end

  def first_name
    return nil unless name.present?
    name.split(' ').first
  end

  def last_name
    return nil unless name.present?
    name.split(' ').last
  end

  def has_profile_image?
    profile_image_url.present?
  end

  def raw_info
    raw_data&.dig('info') || {}
  end

  def raw_credentials
    raw_data&.dig('credentials') || {}
  end

  def raw_extra
    raw_data&.dig('extra') || {}
  end
  
  # Class methods
  def self.find_teammate_by_slack_id(slack_user_id, organization)
    slack
      .where(uid: slack_user_id)
      .joins(:teammate)
      .where(teammates: { organization: organization })
      .first
      &.teammate
  end
  
  def self.find_teammate_by_provider_id(provider, uid, organization)
    where(provider: provider, uid: uid)
      .joins(:teammate)
      .where(teammates: { organization: organization })
      .first
      &.teammate
  end
end
