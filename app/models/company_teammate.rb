class CompanyTeammate < Teammate
  # Company-level teammates can have any combination of permissions
  # They have the highest level of access within the organization
  
  # Associations
  has_many :prompts, foreign_key: 'company_teammate_id', dependent: :destroy
  
  # Company-specific validations
  validate :company_level_permissions
  
  def to_s
    "(#{id}) #{person.display_name} @ #{organization.name}"
  end

  # Company-specific methods
  def can_manage_anything?
    can_manage_employment? && can_manage_maap?
  end
  
  def has_full_access?
    can_manage_employment? && can_manage_maap? && can_create_employment?
  end
  
  # Milestone-related methods (moved from Person model)
  def milestone_attainments
    teammate_milestones.by_milestone_level.includes(:ability)
  end

  def milestone_attainments_count
    teammate_milestones.count
  end

  def has_milestone_attainments?
    teammate_milestones.exists?
  end

  def highest_milestone_for_ability(ability)
    teammate_milestones.where(ability: ability).maximum(:milestone_level)
  end

  def has_milestone_for_ability?(ability, level)
    teammate_milestones.where(ability: ability, milestone_level: level).exists?
  end

  def add_milestone_attainment(ability, level, certified_by)
    teammate_milestones.create!(ability: ability, milestone_level: level, certified_by: certified_by, attained_at: Date.current)
  end

  def remove_milestone_attainment(ability, level)
    teammate_milestones.where(ability: ability, milestone_level: level).destroy_all
  end

  # Assignment-related methods (moved from Person model)
  def active_assignment_tenures
    assignment_tenures.active.where(assignments: { company: organization })
  end

  def assignments_ready_for_finalization_count
    AssignmentCheckIn.joins(:assignment)
                     .where(teammate: self, assignments: { company: organization })
                     .ready_for_finalization
                     .count
  end

  def active_assignments
    assignments.joins(:assignment_tenures)
               .where(assignment_tenures: { 
                 assignments: { company: organization }, 
                 ended_at: nil 
               })
               .where('assignment_tenures.anticipated_energy_percentage > 0')
               .distinct
  end

  # Hierarchy methods (moved from Person model)
  def in_managerial_hierarchy_of?(other_teammate)
    return false unless other_teammate
    return false unless other_teammate.organization == organization
    
    # Use the organization (company) for scoping employment tenures
    company = organization
    
    # Recursively check if this teammate is anywhere in the managerial hierarchy
    # Use a Set to prevent infinite loops from circular references
    visited = Set.new
    
    check_hierarchy = lambda do |teammate, visited_set|
      return false if visited_set.include?(teammate.id)
      visited_set.add(teammate.id)
      
      # Get active employment tenures for this teammate in this company
      # Query directly from database to avoid association caching issues
      tenures = EmploymentTenure.where(teammate: teammate, company: company, ended_at: nil).includes(:manager)
      
      tenures.each do |tenure|
        manager = tenure.manager
        next unless manager
        
        # Get manager's teammate in this organization
        # Query directly from database to avoid association caching issues
        manager_teammate = CompanyTeammate.find_by(organization: company, person: manager)
        next unless manager_teammate
        
        # Found self in the hierarchy
        return true if manager_teammate == self
        
        # Recursively check managers of this manager
        return true if check_hierarchy.call(manager_teammate, visited_set)
      end
      
      false
    end
    
    check_hierarchy.call(other_teammate, visited)
  end

  def has_direct_reports?
    # Check if this teammate manages anyone in the organization
    EmploymentTenure.where(company: organization, manager: person, ended_at: nil)
                    .exists?
  end

  # Current manager method (moved from Person model)
  def current_manager
    employment_tenures.active.first&.manager
  end
  
  private
  
  def company_level_permissions
    # Company teammates can have any combination of permissions
    # No additional restrictions at this level
  end
end
