class Goal < ApplicationRecord
  # Associations
  belongs_to :owner, polymorphic: true, optional: true # presence validated in owner_presence (avoids constantize when owner_type is Teammate)
  belongs_to :creator, class_name: 'CompanyTeammate'
  belongs_to :company, class_name: 'Organization'
  
  has_many :outgoing_links, class_name: 'GoalLink', foreign_key: 'parent_id', dependent: :destroy
  has_many :linked_goals, through: :outgoing_links, source: :child
  
  has_many :incoming_links, class_name: 'GoalLink', foreign_key: 'child_id', dependent: :destroy
  has_many :linking_goals, through: :incoming_links, source: :parent
  
  has_many :goal_check_ins, dependent: :destroy
  has_many :recent_check_ins, -> { recent.limit(3) }, class_name: 'GoalCheckIn'
  has_many :prompt_goals, dependent: :destroy
  has_many :prompts, through: :prompt_goals
  
  # Callbacks
  before_validation :set_company_id
  before_validation :set_explicit_owner_type
  
  # Enums
  enum :goal_type, {
    inspirational_objective: 'inspirational_objective',
    qualitative_key_result: 'qualitative_key_result',
    quantitative_key_result: 'quantitative_key_result',
    stepping_stone_activity: 'stepping_stone_activity'
  }
  
  enum :privacy_level, {
    only_creator: 'only_creator',
    only_creator_and_owner: 'only_creator_and_owner',
    only_creator_owner_and_managers: 'only_creator_owner_and_managers',
    everyone_in_company: 'everyone_in_company'
  }

  enum :initial_confidence, {
    commit: 'commit',
    stretch: 'stretch',
    transform: 'transform'
  }, prefix: true

  # Validations (owner_type_valid before presence so invalid owner_type doesn't constantize removed Teammate)
  validate :owner_type_valid
  validates :title, :goal_type, :privacy_level, :creator, presence: true
  validate :owner_presence
  validates :title, exclusion: { in: [nil, ''], message: "can't be blank" }
  # Target dates are optional - they can be set via timeframe selection or explicitly
  
  validate :title_not_blank_after_strip
  validate :date_ordering
  validate :privacy_level_for_owner_type
  
  # Scopes
  scope :for_teammate, ->(teammate_or_collection) {
    teammates = teammate_or_collection.respond_to?(:each) ? teammate_or_collection : [teammate_or_collection]
    teammate_ids = teammates.map(&:id)
    organization_ids = teammates.map(&:organization_id)

    where(
      "(owner_type = 'CompanyTeammate' AND owner_id IN (?)) OR creator_id IN (?) OR (owner_type IN ('Organization', 'Department', 'Team') AND owner_id IN (?))",
      teammate_ids, teammate_ids, organization_ids
    )
  }
  
  scope :timeframe_now, -> {
    where('most_likely_target_date >= ? AND most_likely_target_date < ?', 
          Date.today, Date.today + 3.months)
  }
  
  scope :timeframe_next, -> {
    where('most_likely_target_date >= ? AND most_likely_target_date < ?',
          Date.today + 3.months, Date.today + 9.months)
  }
  
  scope :timeframe_later, -> {
    where('most_likely_target_date >= ?', Date.today + 9.months)
  }
  
  scope :draft, -> { where(started_at: nil) }
  
  scope :active, -> {
    where(deleted_at: nil)
      .where(completed_at: nil)
      .where.not(started_at: nil)
  }
  
  scope :completed, -> { where.not(completed_at: nil) }
  
  scope :check_in_eligible, -> {
    where.not(goal_type: 'inspirational_objective')
         .where.not(most_likely_target_date: nil)
  }
  
  # Instance methods
  def timeframe
    return :later unless most_likely_target_date
    
    months_away = (most_likely_target_date.year * 12 + most_likely_target_date.month) -
                  (Date.today.year * 12 + Date.today.month)
    
    if months_away < 3
      :now
    elsif months_away < 9
      :next
    else
      :later
    end
  end
  
  def status
    return :deleted if deleted_at.present?
    return :completed if completed_at.present?
    return :active if started_at.present?
    :draft
  end
  
  def goal_category
    return :vision if goal_type == 'inspirational_objective' && most_likely_target_date.nil?
    return :objective if goal_type == 'inspirational_objective' && most_likely_target_date.present?
    return :bad_key_result if %w[qualitative_key_result quantitative_key_result].include?(goal_type) && most_likely_target_date.nil?
    return :key_result if %w[qualitative_key_result quantitative_key_result].include?(goal_type) && most_likely_target_date.present?
    nil
  end
  
  def vision?
    goal_category == :vision
  end
  
  def objective?
    goal_category == :objective
  end
  
  def key_result?
    goal_category == :key_result
  end
  
  def bad_key_result?
    goal_category == :bad_key_result
  end
  
  def needs_target_date?
    goal_type != 'inspirational_objective' && most_likely_target_date.nil?
  end
  
  def needs_start?
    goal_type != 'inspirational_objective' && most_likely_target_date.present? && started_at.nil?
  end
  
  def check_in_eligible?
    !objective? && most_likely_target_date.present?
  end
  
  def has_sub_goals?
    outgoing_links.exists?
  end
  
  def should_show_warning?
    return true if bad_key_result?
    return true if (vision? || objective?) && !has_sub_goals?
    false
  end
  
  def can_be_viewed_by?(person)
    return true if person.og_admin?
    return true if creator.person == person # Always creator can view
    
    case privacy_level
    when 'only_creator'
      false
    when 'only_creator_and_owner'
      if owner_type == 'CompanyTeammate'
        owner.person == person
      elsif owner_type.in?(['Organization', 'Department', 'Team'])
        # Organization owner: check if person belongs directly to owner organization
        person.teammates.exists?(organization: owner)
      else
        false
      end
    when 'only_creator_owner_and_managers'
      if owner_type == 'CompanyTeammate'
        # Owner can always view
        return true if owner.person == person
        # Check if person is in managerial hierarchy of owner's person
        person_teammate = CompanyTeammate.find_by(organization: company, person: person)
        owner_teammate = owner.is_a?(CompanyTeammate) ? owner : CompanyTeammate.find_by(organization: company, person: owner.person)
        return false unless person_teammate && owner_teammate
        person_teammate.in_managerial_hierarchy_of?(owner_teammate)
      elsif owner_type.in?(['Organization', 'Department', 'Team'])
        # Organization owner with only_creator_owner_and_managers:
        # - Direct members of owner organization can see
        # - Check if person belongs directly to owner organization
        person.teammates.exists?(organization: owner)
      else
        false
      end
    when 'everyone_in_company'
      # For any owner type: check if person is teammate in the same company
      return false unless company
      # Check if person has any teammates in the company or its descendants
      org_ids = company.self_and_descendants.map(&:id)
      return false if org_ids.empty?
      person.teammates.where(organization_id: org_ids).exists?
    else
      false
    end
  end
  
  def manages_any_teammate_in_owner_org?(person)
    return false unless owner_type.in?(['Organization', 'Department', 'Team'])
    return false unless company
    
    # Get all teammates who belong directly to the owner organization
    org_teammates = owner.teammates.where(organization: owner)
    
    # Check if person manages any of these teammates
    person_teammate = CompanyTeammate.find_by(organization: company, person: person)
    return false unless person_teammate
    
    org_teammates.any? do |teammate|
      teammate_company_teammate = teammate.is_a?(CompanyTeammate) ? teammate : CompanyTeammate.find_by(organization: company, person: teammate.person)
      teammate_company_teammate && person_teammate.in_managerial_hierarchy_of?(teammate_company_teammate)
    end
  end
  
  def owner_company
    # Now that we have company_id cached, we can just return it
    company
  end
  
  def managers
    return [] unless owner_type == 'CompanyTeammate'
    
    # Get managers from active employment tenures in the company
    return [] unless company
    
    EmploymentTenure.active
      .where(company_teammate: owner, company: company)
      .where.not(manager_teammate_id: nil)
      .includes(manager_teammate: :person)
      .map { |tenure| tenure.manager_teammate&.person }
      .compact
      .uniq
  end
  
  def soft_delete!
    update!(deleted_at: Time.current)
  end
  
  def restore!
    update!(deleted_at: nil)
  end
  
  def soft_deleted?
    deleted_at.present?
  end
  
  def calculated_target_date
    # Return nil if all three dates are nil
    return nil if earliest_target_date.nil? && most_likely_target_date.nil? && latest_target_date.nil?
    
    # Return the non-nil date if only one is set
    non_nil_dates = [earliest_target_date, most_likely_target_date, latest_target_date].compact
    return non_nil_dates.first if non_nil_dates.length == 1
    
    # If multiple dates are set
    today = Date.current
    
    # Use most_likely_target_date if today < most_likely_target_date and it's set
    if most_likely_target_date.present? && today < most_likely_target_date
      return most_likely_target_date
    end
    
    # Else use latest_target_date if today < latest_target_date and it's set
    if latest_target_date.present? && today < latest_target_date
      return latest_target_date
    end
    
    # Else use the latest non-nil date
    non_nil_dates.max
  end
  
  private
  
  def date_ordering
    # Only validate if all dates are present
    return unless earliest_target_date.present? && most_likely_target_date.present? && latest_target_date.present?
    
    if earliest_target_date > most_likely_target_date
      errors.add(:base, "earliest_target_date must be less than or equal to most_likely_target_date")
    end
    
    if most_likely_target_date > latest_target_date
      errors.add(:base, "most_likely_target_date must be less than or equal to latest_target_date")
    end
  end
  
  def title_not_blank_after_strip
    return unless title.present?
    
    if title.strip.blank?
      errors.add(:title, "can't be blank or contain only whitespace")
    end
  end
  
  def privacy_level_for_owner_type
    return unless owner_type && privacy_level

    # Organization/Department/Team owners have restricted privacy options
    if owner_type.in?(['Organization', 'Department', 'Team'])
      if privacy_level == 'only_creator_and_owner'
        errors.add(:privacy_level, 'is not valid for Organization owner')
      end
      # Note: only_creator_owner_and_managers IS valid for Organization owners
    end
  end
  
  def owner_presence
    return if owner_type == 'Teammate' # already invalid; avoid constantize when checking owner
    errors.add(:owner, 'must exist') if owner.blank?
  end

  def owner_type_valid
    return unless owner_type

    # Reject legacy Teammate type before accessing owner (avoids constantize)
    if owner_type == 'Teammate'
      errors.add(:owner_type, 'must be CompanyTeammate, not Teammate')
      return
    end

    return unless owner

    if owner_type == 'CompanyTeammate'
      unless owner.is_a?(CompanyTeammate)
        errors.add(:owner, 'must be a CompanyTeammate')
      end
    elsif owner_type.in?(['Organization', 'Department', 'Team'])
      # Check the actual class matches the specified owner_type
      unless owner.is_a?(Organization) || owner.is_a?(Department) || owner.is_a?(Team)
        errors.add(:owner, 'must be a Department, Team, or Organization')
      end
    else
      # Reject any other owner types
      errors.add(:owner_type, 'must be CompanyTeammate, Organization, Department, or Team')
    end
  end
  
  # Normalize UI "Company" to stored "Organization" so polymorphic owner never constantizes Company
  def set_explicit_owner_type
    self.owner_type = 'Organization' if owner_type == 'Company'
  end

  def set_company_id
    return if company_id.present?
    return unless creator

    company = creator.organization.root_company || creator.organization
    self.company_id = company.id if company
  end
end

