class PersonIdentity < ApplicationRecord
  belongs_to :person
  
  # Validations
  validates :provider, presence: true
  validates :uid, presence: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :uid, uniqueness: { scope: :provider }
  
  # Scopes
  scope :google, -> { where(provider: 'google_oauth2') }
  scope :email, -> { where(provider: 'email') }
  
  # Instance methods
  def google?
    provider == 'google_oauth2'
  end
  
  def email?
    provider == 'email'
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
end
