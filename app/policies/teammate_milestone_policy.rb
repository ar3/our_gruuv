class TeammateMilestonePolicy < ApplicationPolicy
  def new?
    create?
  end

  def create?
    # Any authenticated teammate can award milestones
    return false unless viewing_teammate
    return false if viewing_teammate.terminated?
    true
  end

  def show?
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false if viewing_teammate.terminated?
    
    # Teammate who was awarded can view
    return true if viewing_teammate == record.teammate
    
    # Managers of the teammate (people above them) can view
    return true if viewing_teammate.in_managerial_hierarchy_of?(record.teammate)
    
    # Anyone with can_manage_employment? permission on the awarded teammate's company_teammate
    return true if viewing_teammate.can_manage_employment? && 
                  viewing_teammate.organization == record.teammate.organization
    
    false
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      
      # Users can see milestones for:
      # 1. Their own milestones
      # 2. Milestones for teammates they manage
      # 3. All milestones if they have manage_employment permission
      
      if viewing_teammate.can_manage_employment?
        # If they have manage_employment, show all milestones in their organization
        scope.joins(:teammate)
             .where(teammates: { organization_id: viewing_teammate.organization_id })
      else
        # Otherwise, only show their own milestones and milestones for their reports
        teammate_ids = [viewing_teammate.id]
        
        # Get all reports using EmployeeHierarchyQuery
        reports = EmployeeHierarchyQuery.new(
          person: viewing_teammate.person,
          organization: viewing_teammate.organization
        ).call
        
        report_teammate_ids = Teammate
          .where(organization: viewing_teammate.organization, person_id: reports.map { |r| r[:person_id] })
          .pluck(:id)
        
        teammate_ids.concat(report_teammate_ids)
        
        scope.where(teammate_id: teammate_ids)
      end
    end
  end
end

