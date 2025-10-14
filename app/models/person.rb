class Person < ApplicationRecord
  include PgSearch::Model
  
  # Associations
  has_many :person_identities, dependent: :destroy
  has_many :observations, foreign_key: :observer_id, dependent: :destroy
  has_many :maap_snapshots, foreign_key: :employee_id, dependent: :destroy

  # Milestone-related methods
  def milestone_attainments(organization)
    teammate = teammates.find_by(organization: organization)
    teammate&.teammate_milestones&.by_milestone_level&.includes(:ability) || []
  end

  def milestone_attainments_count(organization)
    teammate = teammates.find_by(organization: organization)
    teammate&.teammate_milestones&.count || 0
  end

  def has_milestone_attainments?(organization)
    teammate = teammates.find_by(organization: organization)
    teammate&.teammate_milestones&.exists? || false
  end

  def highest_milestone_for_ability(ability, organization)
    teammate = teammates.find_by(organization: organization)
    teammate&.teammate_milestones&.where(ability: ability)&.maximum(:milestone_level)
  end

  def has_milestone_for_ability?(ability, level, organization)
    teammate = teammates.find_by(organization: organization)
    teammate&.teammate_milestones&.where(ability: ability, milestone_level: level)&.exists? || false
  end

  def add_milestone_attainment(ability, level, certified_by, organization)
    teammate = teammates.find_by(organization: organization)
    teammate&.teammate_milestones&.create!(ability: ability, milestone_level: level, certified_by: certified_by, attained_at: Date.current)
  end

  def remove_milestone_attainment(ability, level, organization)
    teammate = teammates.find_by(organization: organization)
    teammate&.teammate_milestones&.where(ability: ability, milestone_level: level)&.destroy_all
  end


  def active_assignment_tenures(company=nil)
    company = current_organization&.root_company if company.nil?
    teammate = teammates.find_by(organization: company)
    return [] unless teammate
    
    if company.nil?
      return teammate.assignment_tenures.active
    else
      teammate.assignment_tenures.active.where(assignments: { company: company })
    end
  end

  # Scopes for active assignments in a specific company
  def assignments_ready_for_finalization_count(company=nil)
    company = current_organization&.root_company if company.nil?
    teammate = teammates.find_by(organization: company)
    return 0 unless teammate
    
    if company.nil?
      AssignmentCheckIn.joins(:assignment)
                       .where(teammate: teammate)
                       .ready_for_finalization
                       .count
    else
      AssignmentCheckIn.joins(:assignment)
                       .where(teammate: teammate, assignments: { company: company })
                       .ready_for_finalization
                       .count
    end
  end

  def active_assignments(company=nil)
    company = current_organization&.root_company if company.nil?
    teammate = teammates.find_by(organization: company)
    return [] unless teammate
    
    if company.nil?
      return teammate.assignments.joins(:assignment_tenures)
                         .where('assignment_tenures.anticipated_energy_percentage > 0')
                         .where(assignment_tenures: { ended_at: nil })
                         .distinct
    else
      teammate.assignments.joins(:assignment_tenures)
                .where(assignment_tenures: { 
                  assignments: { company: company }, 
                  ended_at: nil 
                })
                .where('assignment_tenures.anticipated_energy_percentage > 0')
                .distinct
    end
  end
  has_many :teammates, dependent: :destroy
  has_many :addresses, dependent: :destroy
  belongs_to :current_organization, class_name: 'Organization', optional: true
  
  # Associations through teammates
  has_many :huddle_participants, through: :teammates, source: :huddle_participants
  has_many :huddle_feedbacks, through: :teammates, source: :huddle_feedbacks
  has_many :employment_tenures, through: :teammates, source: :employment_tenures
  
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
    Teammate.can_manage_employment_in_hierarchy?(self, organization)
  end
  
  def can_create_employment?(organization)
    Teammate.can_create_employment?(self, organization)
  end
  
  # Organization context methods
  def current_organization_or_default
    current_organization || Organization.companies.first
  end
  
  def switch_to_organization(organization)
    update!(current_organization: organization)
  end
  
  def available_organizations
    # Return organizations where person is at least a follower
    Organization.joins(:teammates)
                .where(teammates: { person: self })
                .order(:type, :name)
  end
  
  def available_companies
    Organization.companies.order(:type, :name)
  end
  
  def followable_organizations
    # Return organizations that have public assignments, abilities, or positions
    Organization.joins("LEFT JOIN assignments ON assignments.company_id = organizations.id AND assignments.became_public_at IS NOT NULL")
                .joins("LEFT JOIN abilities ON abilities.organization_id = organizations.id AND abilities.became_public_at IS NOT NULL")
                .joins("LEFT JOIN positions ON positions.position_type_id IN (SELECT id FROM position_types WHERE organization_id = organizations.id) AND positions.became_public_at IS NOT NULL")
                .where("assignments.id IS NOT NULL OR abilities.id IS NOT NULL OR positions.id IS NOT NULL")
                .distinct
                .order(:type, :name)
  end
  
  def can_follow_organization?(organization)
    # Check if organization has public content and person is not already a teammate
    has_public_content = organization.assignments.publicly_available.exists? ||
                        organization.abilities.publicly_available.exists? ||
                        organization.positions.publicly_available.exists?
    
    not_already_teammate = !teammates.exists?(organization: organization)
    
    has_public_content && not_already_teammate
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
  
  # Permission checking methods
  def can_manage_employment?(organization)
    Teammate.can_manage_employment_in_hierarchy?(self, organization)
  end
  
  def can_manage_maap?(organization)
    Teammate.can_manage_maap_in_hierarchy?(self, organization)
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

  def in_managerial_hierarchy_of?(other_person)
    return false unless current_organization
    
    other_teammate = other_person.teammates.find_by(organization: current_organization)
    return false unless other_teammate
    
    other_teammate.employment_tenures.active.where(company: current_organization).exists?
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
    ActiveEmploymentTenureQuery.new(person: self, organization: organization).first
  end

  def current_manager_for(organization)
    active_employment_tenure_for(organization)&.manager
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
      email: 'C'
    },
    using: {
      tsearch: { prefix: true, any_word: true }
    }
  
  multisearchable against: [:first_name, :last_name, :email]
end
