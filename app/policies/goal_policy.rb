class GoalPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    admin_bypass? || record.can_be_viewed_by?(viewing_teammate.person)
  end

  def new?
    admin_bypass? || user_is_teammate_of_company?
  end

  def create?
    admin_bypass? || user_is_teammate_of_company?
  end

  def update?
    admin_bypass? || user_is_creator_or_owner?
  end

  def destroy?
    admin_bypass? || user_is_creator?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person.og_admin?
        scope.all
      else
        # Use organization from viewing_teammate
        company = actual_organization&.root_company || actual_organization
        return scope.none unless company
        
        # Filter by company_id - don't filter by deleted/completed here,
        # let the controller handle that based on user preferences
        scope.where(company_id: company.id)
      end
    end
  end

  private

  def user_is_teammate?
    # User is always a teammate (that's what current_company_teammate is)
    true
  end

  def user_is_teammate_of_company?
    # Get the company (root organization) from viewing_teammate
    company = actual_organization.root_company || actual_organization
    return false unless company
    
    # Check if viewing_teammate's organization is in the company hierarchy
    company.self_and_descendants.include?(actual_organization)
  end

  def user_is_creator?
    return false unless record&.creator
    return false unless viewing_teammate
    
    viewing_teammate.person == record.creator.person
  end

  def user_is_creator_or_owner?
    return false unless record
    return false unless viewing_teammate
    
    # User is creator
    return true if user_is_creator?
    
    person = viewing_teammate.person
    
    # User is owner (if owner is CompanyTeammate)
    if record.owner_type == 'CompanyTeammate'
      # Check if viewing_teammate is the owner Teammate, or if person matches owner's person
      return true if record.owner == viewing_teammate || record.owner.person == person
    end
    
    # User is direct member of owner organization (if owner is Company/Department/Team)
    # Rails polymorphic associations use "Organization" as owner_type for STI subclasses
    if record.owner_type == 'Organization' || record.owner_type.in?(['Company', 'Department', 'Team'])
      teammate_org = viewing_teammate.organization
      # Check if viewing_teammate is directly in the owner organization (not just in the company hierarchy)
      # For everyone_in_company privacy, allow direct members of owner organization to update
      # For other privacy levels, also allow direct members
      return true if teammate_org == record.owner
      
      # Don't allow members of descendant organizations to update (only direct members)
      # This distinguishes "direct member of owner org" from "any member of company"
      return false
    end
    
    false
  end
end


