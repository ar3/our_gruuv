class PromptPolicy < ApplicationPolicy
  def index?
    # Any teammate in company can see prompts index
    return true if admin_bypass?
    return false unless viewing_teammate
    true
  end

  def show?
    return true if admin_bypass?
    return false unless viewing_teammate && record
    return false unless record.company_teammate
    
    # Teammate owns prompt
    return true if viewing_teammate.person == record.company_teammate.person
    
    # User has prompts management permission
    return true if viewing_teammate.can_manage_prompts?
    
    # Check if user is in managerial hierarchy of the prompt's teammate
    organization = actual_organization || viewing_teammate.organization
    return false unless organization
    
    viewing_teammate.is_a?(CompanyTeammate) && record.company_teammate && viewing_teammate.in_managerial_hierarchy_of?(record.company_teammate)
  end

  def create?
    # Any teammate in company can create prompts
    return true if admin_bypass?
    return false unless viewing_teammate
    true
  end

  def update?
    # Same as show? but also requires prompt to be open
    return false unless show?
    return false unless record.open?
    true
  end

  def close?
    # Same as update?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      
      if person&.og_admin?
        scope.all
      else
        organization = actual_organization || viewing_teammate.organization
        return scope.none unless organization
        
        company = organization.root_company || organization
        
        # If user has can_manage_prompts, they can see all prompts in the company
        if viewing_teammate.can_manage_prompts?
          scope.where(company_teammate: CompanyTeammate.where(organization: company))
        else
          # Get all prompts the user has access to:
          # 1. Prompts owned by the user
          # 2. Prompts owned by people the user manages (direct and indirect reports)
          
          accessible_teammate_ids = [viewing_teammate.id]
          
          # Use EmployeeHierarchyQuery to get all people the user manages efficiently
          # This finds direct and indirect reports (people in the user's managerial hierarchy)
          hierarchy_query = EmployeeHierarchyQuery.new(person: person, organization: organization)
          reports = hierarchy_query.call
          report_person_ids = reports.map { |r| r[:person_id] }
          
          if report_person_ids.any?
            report_teammates = CompanyTeammate.where(organization: company, person_id: report_person_ids)
            accessible_teammate_ids += report_teammates.pluck(:id)
          end
          
          scope.where(company_teammate_id: accessible_teammate_ids)
        end
      end
    end
  end
end

