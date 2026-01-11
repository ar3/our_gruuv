require 'set'

class Person < ApplicationRecord
  include PgSearch::Model
  
  # Associations
  has_many :person_identities, dependent: :destroy
  has_many :observations, foreign_key: :observer_id, dependent: :destroy
  has_many :maap_snapshots, foreign_key: :employee_id, dependent: :destroy
  has_many :page_visits, dependent: :destroy
  has_one :user_preference, dependent: :destroy

  has_many :teammates, dependent: :destroy
  has_many :addresses, dependent: :destroy
  
  # Associations through teammates
  has_many :huddle_participants, through: :teammates, source: :huddle_participants
  has_many :huddle_feedbacks, through: :teammates, source: :huddle_feedbacks
  has_many :employment_tenures, through: :teammates, source: :employment_tenures
  has_many :slack_identities, -> { where(provider: 'slack') }, through: :teammates, source: :teammate_identities
  
  # Callbacks
  before_save :normalize_phone_number
  
  # Validations
  validates :unique_textable_phone_number, uniqueness: true, allow_blank: true
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :gender_identity, inclusion: { 
    in: %w[man woman non_binary genderqueer genderfluid agender two_spirit prefer_not_to_say other], 
    allow_blank: true 
  }
  validates :pronouns, inclusion: { 
    in: %w[he/him she/her they/them he/they she/they other prefer_not_to_say], 
    allow_blank: true 
  }
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
  
  def casual_name
    return preferred_name if preferred_name.present?
    parts = [
      first_name, 
      last_name.present? ? "#{last_name[0]}." : nil, 
      suffix].compact
    parts.join(' ')
  end
  # Instance methods
  
  
  def display_name
    if preferred_name.present?
      preferred_name
    elsif full_name.present?
      full_name
    else
      email
    end
  end
  
  def last_first_display_name
    return "#{last_name}, #{first_name} (#{preferred_name})" if last_name.present? && first_name.present? && preferred_name.present? && preferred_name != first_name
    return "#{last_name}, #{first_name}" if last_name.present? && first_name.present?
    return "#{last_name}, #{preferred_name}" if last_name.present? && preferred_name.present?
    return "#{last_name}" if last_name.present?
    return "#{first_name}" if first_name.present?
    return "#{preferred_name}" if preferred_name.present?
    return "#{email}"
  end

  def government_first_then_last_display_name
    return "#{first_name} #{last_name_with_suffix} (#{preferred_name})" if last_name.present? && first_name.present? && preferred_name.present? && preferred_name != first_name
    return "#{first_name} #{last_name_with_suffix}" if last_name.present? && first_name.present?
    return "#{preferred_name} #{last_name_with_suffix}" if last_name.present? && preferred_name.present?
    return "#{last_name_with_suffix}" if last_name.present?
    return "#{first_name}" if first_name.present?
    return "#{preferred_name}" if preferred_name.present?
    return "#{email}"
  end

  def preferred_first_then_last_display_name
    return "#{preferred_name} #{last_name_with_suffix}" if last_name.present? && preferred_name.present?
    return "#{first_name} #{last_name_with_suffix}" if last_name.present? && first_name.present?
    return "#{last_name_with_suffix}" if last_name.present?
    return "#{preferred_name}" if preferred_name.present?
    return "#{first_name}" if first_name.present?
    return "#{email}"
  end

  def last_name_with_suffix
    return "#{last_name} #{suffix}" if suffix.present?
    return "#{last_name}"
  end

  def google_profile_image_url
    google_identity&.profile_image_url
  end

  def latest_profile_image_url
    # Check all person_identities and teammate_identities for profile images
    # Return the most recently updated one
    all_identities = []
    
    # Get all person_identities with profile images
    person_identities.where.not(profile_image_url: nil).find_each do |identity|
      all_identities << { url: identity.profile_image_url, updated_at: identity.updated_at }
    end
    
    # Get all teammate_identities with profile images through all teammates
    teammates.includes(:teammate_identities).find_each do |teammate|
      teammate.teammate_identities.where.not(profile_image_url: nil).find_each do |identity|
        all_identities << { url: identity.profile_image_url, updated_at: identity.updated_at }
      end
    end
    
    # Return the most recently updated profile image
    return nil if all_identities.empty?
    all_identities.max_by { |i| i[:updated_at] }[:url]
  end
  
  def timezone_or_default
    timezone.present? ? timezone : 'Eastern Time (US & Canada)'
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
  




  # Admin methods
  def admin?
    og_admin?
  end


  # Organization context methods
  def available_organizations
    # Return organizations where person has active teammates (not terminated)
    Organization.joins(:teammates)
                .where(teammates: { person: self, last_terminated_at: nil })
                .order(:type, :name)
  end
  
  def active_teammates
    teammates.where(last_terminated_at: nil)
  end
  
  def available_companies
    Organization.companies.order(:type, :name)
  end
  
  def followable_organizations
    # Return organizations that have assignments, abilities, or positions
    Organization.joins("LEFT JOIN assignments ON assignments.company_id = organizations.id")
                .joins("LEFT JOIN abilities ON abilities.organization_id = organizations.id")
                .joins("LEFT JOIN positions ON positions.position_type_id IN (SELECT id FROM position_types WHERE organization_id = organizations.id)")
                .where("assignments.id IS NOT NULL OR abilities.id IS NOT NULL OR positions.id IS NOT NULL")
                .distinct
                .order(:type, :name)
  end
  
  def can_follow_organization?(organization)
    # Check if organization has content and person is not already a teammate
    has_content = organization.assignments.exists? ||
                  organization.abilities.exists? ||
                  organization.positions.exists?
    
    not_already_teammate = !teammates.exists?(organization: organization)
    
    has_content && not_already_teammate
  end
  
  def last_huddle
    Huddle.joins(huddle_participants: :teammate)
          .where(teammates: { person: self })
          .recent
          .first
  end
  
  def last_huddle_company
    last_huddle&.organization&.root_company
  end
  
  def last_huddle_team
    last_huddle&.organization&.team? ? last_huddle.organization : nil
  end
  
  # Employment tenure checking methods
  def active_employment_tenure_in?(organization)
    teammate = teammates.find_by(organization: organization)
    teammate&.employment_tenures&.active&.where(company: organization)&.exists? || false
  end

  def employment_status_text_for(organization)
    teammate = teammates.find_by(organization: organization)
    return "Never been employed at #{organization.display_name}" unless teammate
    
    tenures = teammate.employment_tenures.where(company: organization).order(started_at: :desc)
    
    if tenures.empty?
      "Never been employed at #{organization.display_name}"
    elsif active_employment_tenure_in?(organization)
      current_tenure = tenures.active.first
      "#{current_tenure.position.display_name}"
    else
      last_tenure = tenures.first
      "Last employed #{time_ago_in_words(last_tenure.ended_at)} as a #{last_tenure.position.display_name}"
    end
  end


  # Huddle participation methods
  def huddle_playbook_stats
    huddle_participants.joins(:huddle)
                       .includes(huddle: :huddle_playbook)
                       .group_by { |p| p.huddle.huddle_playbook }
  end

  def total_huddle_participations
    huddle_participants.count
  end

  def total_huddle_playbooks
    huddle_participants.joins(:huddle).distinct.count(:huddle_playbook_id)
  end

  def total_feedback_given
    huddle_feedbacks.count
  end

  def has_huddle_participation?
    huddle_participants.exists?
  end

  def has_given_feedback_for_huddle?(huddle)
    huddle_feedbacks.where(huddle: huddle).exists?
  end

  def huddle_stats_for_playbook(playbook)
    playbook_participations = huddle_participants.joins(:huddle).where(huddles: { huddle_playbook: playbook })
    
    total_huddles_held = playbook.huddles.count
    participations_count = playbook_participations.count
    feedback_count = huddle_feedbacks.joins(:huddle).where(huddles: { huddle_playbook: playbook }).count
    
    # Calculate average rating for this person's feedback in this playbook
    ratings = huddle_feedbacks.joins(:huddle)
                              .where(huddles: { huddle_playbook: playbook })
                              .pluck(:informed_rating, :connected_rating, :goals_rating, :valuable_rating)
    
    average_rating = if ratings.any?
      total_ratings = ratings.flatten.sum
      (total_ratings.to_f / ratings.flatten.count).round(1)
    else
      0
    end
    
    {
      total_huddles_held: total_huddles_held,
      participations_count: participations_count,
      participation_percentage: total_huddles_held > 0 ? ((participations_count.to_f / total_huddles_held) * 100).round(1) : 0,
      feedback_count: feedback_count,
      average_rating: average_rating
    }
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
  
  # Active employment tenure convenience methods
  def active_employment_tenure_for(organization)
    company = organization.root_company || organization
    teammates.find_by(organization: company)&.active_employment_tenure
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
    
    # Use FullNameParser for consistent name parsing
    name_parts = FullNameParser.new(@full_name)
    
    self.first_name = name_parts.first_name
    self.middle_name = name_parts.middle_name
    self.last_name = name_parts.last_name
    self.suffix = name_parts.suffix
  end
  
  # pg_search configuration
  pg_search_scope :search_by_full_text,
    against: {
      first_name: 'A',
      last_name: 'A',
      middle_name: 'B',
      preferred_name: 'A',
      suffix: 'B',
      email: 'C',
      unique_textable_phone_number: 'C'
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }
  
  multisearchable against: [:first_name, :last_name, :middle_name, :preferred_name, :suffix, :email, :unique_textable_phone_number],
    associated_against: {
      slack_identities: [:name]
    }
end
