class Person < ApplicationRecord
  # Associations
  has_many :huddle_participants, dependent: :destroy
  has_many :huddles, through: :huddle_participants
  has_many :huddle_feedbacks, dependent: :destroy
  has_many :person_identities, dependent: :destroy
  has_many :employment_tenures, dependent: :destroy
  has_many :assignment_tenures, dependent: :destroy
  has_many :person_organization_accesses, dependent: :destroy
  belongs_to :current_organization, class_name: 'Organization', optional: true
  
  # Callbacks
  before_save :normalize_phone_number
  
  # Validations
  validates :unique_textable_phone_number, uniqueness: true, allow_blank: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :ensure_valid_timezone

  
  # Virtual attribute for full name - getter and setter methods
  def full_name
    parts = [first_name, middle_name, last_name, suffix].compact
    parts.join(' ')
  end
  
  def full_name=(value)
    @full_name = value
    parse_full_name
  end
  
  # Instance methods
  
  
  def display_name
    full_name.present? ? full_name : email
  end
  
  def timezone_or_default
    timezone.present? ? timezone : 'Eastern Time (US & Canada)'
  end
  
  def format_time_in_user_timezone(time)
    timezone_name = timezone_or_default
    time.in_time_zone(timezone_name).strftime('%B %d, %Y at %I:%M %p %Z')
  end
  
  # Safely set timezone with validation
  def safe_timezone=(value)
    if value.blank?
      self.timezone = nil
    elsif ActiveSupport::TimeZone.all.map(&:name).include?(value)
      self.timezone = value
    else
      Rails.logger.warn "Invalid timezone attempted: #{value}, setting to Eastern Time"
      self.timezone = 'Eastern Time (US & Canada)'
    end
  end
  
  def format_time_in_user_timezone(time)
    return time.in_time_zone('Eastern Time (US & Canada)').strftime('%B %d, %Y at %I:%M %p %Z') unless timezone.present?
    
    time.in_time_zone(timezone).strftime('%B %d, %Y at %I:%M %p %Z')
  end
  




  # Admin methods
  def admin?
    og_admin?
  end
  
  # Permission helper methods
  def can_manage_employment?(organization)
    PersonOrganizationAccess.can_manage_employment_in_hierarchy?(self, organization)
  end
  
  def can_create_employment?(organization)
    PersonOrganizationAccess.can_create_employment?(self, organization)
  end
  
  # Organization context methods
  def current_organization_or_default
    current_organization || Organization.companies.first
  end
  
  def switch_to_organization(organization)
    update!(current_organization: organization)
  end
  
  def available_organizations
    Organization.all.order(:type, :name)
  end
  
  def available_companies
    Organization.companies.order(:type, :name)
  end
  
  def last_huddle
    huddles.recent.first
  end
  
  def last_huddle_company
    last_huddle&.organization&.root_company
  end
  
  def last_huddle_team
    last_huddle&.organization&.team? ? last_huddle.organization : nil
  end
  
  # Permission checking methods
  def can_manage_employment?(organization)
    PersonOrganizationAccess.can_manage_employment_in_hierarchy?(self, organization)
  end
  
  def can_manage_maap?(organization)
    PersonOrganizationAccess.can_manage_maap_in_hierarchy?(self, organization)
  end

  # Employment tenure checking methods
  def active_employment_tenure_in?(organization)
    employment_tenures.active.where(organization: organization).exists?
  end

  def in_managerial_hierarchy_of?(other_person)
    return false unless current_organization
    
    # Check if this person manages the other person through employment tenures
    # This is a simplified version - you might want to expand this logic
    other_person.employment_tenures.active.where(organization: current_organization).exists?
  end
  
  # Identity methods
  def google_identity
    person_identities.google.first
  end
  
  def email_identity
    person_identities.email.first
  end
  
  def has_google_identity?
    person_identities.google.exists?
  end
  
  def has_email_identity?
    person_identities.email.exists?
  end
  
  def find_or_create_email_identity
    person_identities.email.find_or_create_by!(email: email) do |identity|
      identity.uid = email # Use email as UID for email identities
    end
  end

  def has_multiple_google_accounts?
    person_identities.google.count > 1
  end

  def primary_google_identity
    person_identities.google.first
  end

  def all_google_emails
    person_identities.google.pluck(:email)
  end

  def can_disconnect_identity?(identity)
    return false if identity.email? # Don't allow disconnecting email identity
    return false if identity.google? && person_identities.google.count == 1
    true
  end
  
  private
  
  def normalize_phone_number
    # Convert empty strings to nil to avoid unique constraint violations
    self.unique_textable_phone_number = nil if unique_textable_phone_number.blank?
  end
  
  def ensure_valid_timezone
    return if timezone.blank?
    
    unless TimezoneService.valid_timezone?(timezone)
      self.timezone = TimezoneService::DEFAULT_TIMEZONE
    end
  end
  
  def parse_full_name
    return unless @full_name.present?
    
    # Split the name into parts
    name_parts = @full_name.strip.split(/\s+/)
    
    case name_parts.length
    when 1
      self.first_name = name_parts[0]
    when 2
      self.first_name = name_parts[0]
      self.last_name = name_parts[1]
    when 3
      self.first_name = name_parts[0]
      self.middle_name = name_parts[1]
      self.last_name = name_parts[2]
    else
      # For 4+ parts, assume first is first name, last is last name, rest is middle
      self.first_name = name_parts[0]
      self.last_name = name_parts[-1]
      self.middle_name = name_parts[1..-2].join(' ') if name_parts.length > 2
    end
  end
end
