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
    "#{provider.titleize} (#{email})"
  end
end
