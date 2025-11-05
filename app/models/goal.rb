class Goal < ApplicationRecord
  # Associations
  belongs_to :owner, polymorphic: true
  belongs_to :creator, class_name: 'Teammate'
  
  has_many :outgoing_links, class_name: 'GoalLink', foreign_key: 'this_goal_id', dependent: :destroy
  has_many :linked_goals, through: :outgoing_links, source: :that_goal
  
  has_many :incoming_links, class_name: 'GoalLink', foreign_key: 'that_goal_id', dependent: :destroy
  has_many :linking_goals, through: :incoming_links, source: :this_goal
  
  # Enums
  enum :goal_type, {
    inspirational_objective: 'inspirational_objective',
    qualitative_key_result: 'qualitative_key_result',
    quantitative_key_result: 'quantitative_key_result'
  }
  
  enum :privacy_level, {
    only_creator: 'only_creator',
    only_creator_and_owner: 'only_creator_and_owner',
    only_creator_owner_and_managers: 'only_creator_owner_and_managers',
    everyone_in_company: 'everyone_in_company'
  }
  
  # Validations
  validates :title, :goal_type, :privacy_level, :owner, :creator, presence: true
  # Target dates are optional - they can be set via timeframe selection or explicitly
  
  validate :date_ordering
  validate :privacy_level_for_owner_type
  
  # Scopes
  scope :for_teammate, ->(teammate_or_collection) {
    teammates = teammate_or_collection.respond_to?(:each) ? teammate_or_collection : [teammate_or_collection]
    teammate_ids = teammates.map(&:id)
    person_ids = teammates.map(&:person_id)
    organization_ids = teammates.map(&:organization_id)
    
    where(
      "(owner_type = 'Person' AND owner_id IN (?)) OR creator_id IN (?) OR (owner_type = 'Organization' AND owner_id IN (?))",
      person_ids, teammate_ids, organization_ids
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
  
  def has_sub_goals?
    outgoing_links.exists?(link_type: 'this_is_key_result_of_that')
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
      if owner_type == 'Person'
        owner_id == person.id
      else
        # Organization owner: check if person belongs directly to owner organization
        person.teammates.exists?(organization: owner)
      end
    when 'only_creator_owner_and_managers'
      if owner_type == 'Person'
        # Owner can always view
        return true if owner_id == person.id
        # Check if person is in managerial hierarchy of owner
        # Use creator's organization (company) for the check
        company = creator.organization.root_company || creator.organization
        person.in_managerial_hierarchy_of?(owner, company)
      else
        # Organization owner with only_creator_owner_and_managers:
        # - Direct members of owner organization can see
        # - Check if person belongs directly to owner organization
        person.teammates.exists?(organization: owner)
      end
    when 'everyone_in_company'
      if owner_type == 'Person'
        # For Person owner: check if person is teammate in the same company as owner
        owner_company = owner.teammates.joins(:organization).where(organizations: { type: 'Company' }).first&.organization
        return false unless owner_company
        person.teammates.exists?(organization: owner_company)
      else
        # For Organization owner: check owner_company
        # Use owner_company method which handles traversal to root company
        company = owner_company
        return false unless company
        # Check if person is a teammate in the company or any of its descendants
        # This includes the company itself and all teams/departments under it
        org_ids = company.self_and_descendants.map(&:id)
        person.teammates.where(organization_id: org_ids).exists?
      end
    else
      false
    end
  end
  
  def manages_any_teammate_in_owner_org?(person)
    return false unless owner_type == 'Organization'
    return false unless owner_company
    
    # Get all teammates who belong directly to the owner organization
    org_teammates = owner.teammates.where(organization: owner)
    
    # Check if person manages any of these teammates
    org_teammates.any? do |teammate|
      person.in_managerial_hierarchy_of?(teammate.person, owner_company)
    end
  end
  
  def owner_company
    return nil if owner_type == 'Person'
    return nil unless owner_type == 'Organization'
    
    # Get owner record - reload to ensure we have parent association available
    owner_record = Organization.find(owner_id)
    
    # If owner is already a Company, return it
    return owner_record if owner_record.type == 'Company'
    
    # Use root_company method which handles traversal up the parent chain
    # root_company will traverse parent_id if parent association isn't loaded
    owner_record.root_company
  end
  
  def managers
    return [] unless owner_type == 'Person'
    
    # Get managers from active employment tenures in the creator's organization
    company = creator.organization.root_company
    return [] unless company
    
    owner_teammate = owner.teammates.find_by(organization: company)
    return [] unless owner_teammate
    
    EmploymentTenure.active
      .where(teammate: owner_teammate, company: company)
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
  
  def privacy_level_for_owner_type
    return unless owner_type && privacy_level
    
    if owner_type == 'Organization'
      if privacy_level == 'only_creator_and_owner'
        errors.add(:privacy_level, 'is not valid for Organization owner')
      end
      # Note: only_creator_owner_and_managers IS valid for Organization owners
    end
  end
end

