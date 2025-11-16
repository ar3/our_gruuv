class Goal < ApplicationRecord
  # Associations
  belongs_to :owner, polymorphic: true
  belongs_to :creator, class_name: 'Teammate'
  belongs_to :company, class_name: 'Organization'
  
  has_many :outgoing_links, class_name: 'GoalLink', foreign_key: 'parent_id', dependent: :destroy
  has_many :linked_goals, through: :outgoing_links, source: :child
  
  has_many :incoming_links, class_name: 'GoalLink', foreign_key: 'child_id', dependent: :destroy
  has_many :linking_goals, through: :incoming_links, source: :parent
  
  has_many :goal_check_ins, dependent: :destroy
  has_many :recent_check_ins, -> { recent.limit(3) }, class_name: 'GoalCheckIn'
  
  # Callbacks
  before_validation :set_company_id
  
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
  
  # Validations
  validates :title, :goal_type, :privacy_level, :owner, :creator, presence: true
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
      "(owner_type = 'Teammate' AND owner_id IN (?)) OR creator_id IN (?) OR (owner_type = 'Organization' AND owner_id IN (?))",
      teammate_ids, teammate_ids, organization_ids
    )
  }
  
  scope :now, -> {
    where('most_likely_target_date >= ? AND most_likely_target_date < ?', 
          Date.today, Date.today + 3.months)
  }
  
  scope :next_timeframe, -> {
    where('most_likely_target_date >= ? AND most_likely_target_date < ?',
          Date.today + 3.months, Date.today + 9.months)
  }
  
  scope :later, -> {
    where('most_likely_target_date >= ?', Date.today + 9.months)
  }
  
  scope :draft, -> { where(started_at: nil) }
  
  scope :active, -> {
    where.not(started_at: nil)
      .where(completed_at: nil)
      .where(cancelled_at: nil)
  }
  
  scope :completed, -> { where.not(completed_at: nil) }
  scope :cancelled, -> { where.not(cancelled_at: nil) }
  
  scope :check_in_eligible, -> {
    where.not(goal_type: 'inspirational_objective')
         .where.not(most_likely_target_date: nil)
  }
  
  # Soft delete
  default_scope { where(deleted_at: nil) }
  scope :with_deleted, -> { unscope(where: :deleted_at) }
  
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
    return :cancelled if cancelled_at.present?
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
      if owner_type == 'Teammate'
        owner.person == person
      elsif owner_type == 'Organization' && owner.is_a?(Organization)
        # Organization owner: check if person belongs directly to owner organization
        person.teammates.exists?(organization: owner)
      else
        false
      end
    when 'only_creator_owner_and_managers'
      if owner_type == 'Teammate'
        # Owner can always view
        return true if owner.person == person
        # Check if person is in managerial hierarchy of owner's person
        person.in_managerial_hierarchy_of?(owner.person, company)
      elsif owner_type == 'Organization' && owner.is_a?(Organization)
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
    return false unless owner_type == 'Organization' && owner.is_a?(Organization)
    return false unless company
    
    # Get all teammates who belong directly to the owner organization
    org_teammates = owner.teammates.where(organization: owner)
    
    # Check if person manages any of these teammates
    org_teammates.any? do |teammate|
      person.in_managerial_hierarchy_of?(teammate.person, company)
    end
  end
  
  def owner_company
    # Now that we have company_id cached, we can just return it
    company
  end
  
  def managers
    return [] unless owner_type == 'Teammate'
    
    # Get managers from active employment tenures in the company
    return [] unless company
    
    EmploymentTenure.active
      .where(teammate: owner, company: company)
      .where.not(manager_id: nil)
      .includes(:manager)
      .map(&:manager)
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
    
    # Rails polymorphic associations use the base class name for STI, so
    # Company/Department/Team all show up as "Organization" in owner_type
    if owner_type == 'Organization' && owner.is_a?(Organization)
      if privacy_level == 'only_creator_and_owner'
        errors.add(:privacy_level, 'is not valid for Organization owner')
      end
      # Note: only_creator_owner_and_managers IS valid for Organization owners
    end
  end
  
  def set_company_id
    return if company_id.present?
    return unless creator
    
    company = creator.organization.root_company || creator.organization
    self.company_id = company.id if company&.company?
  end
end

