class Person < ApplicationRecord
  # Associations
  has_many :huddle_participants, dependent: :destroy
  has_many :huddles, through: :huddle_participants
  has_many :huddle_feedbacks, dependent: :destroy
  belongs_to :current_organization, class_name: 'Organization', optional: true
  
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
  
  def last_huddle
    huddles.recent.first
  end
  
  def last_huddle_company
    last_huddle&.organization&.root_company
  end
  
  def last_huddle_team
    last_huddle&.organization&.team? ? last_huddle.organization : nil
  end
  
  private
  
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
