class GoalPolicy < ApplicationPolicy
  def index?
    admin_bypass? || user_is_teammate_of_company?
  end

  def show?
    admin_bypass? || record.can_be_viewed_by?(actual_user)
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
      if actual_user.og_admin?
        scope.all
      elsif user.respond_to?(:pundit_organization) && user.pundit_organization
        company = user.pundit_organization.company? ? user.pundit_organization : user.pundit_organization.root_company
        return scope.none unless company
        
        # Simplified: only filter by company_id
        scope.where(deleted_at: nil, company_id: company.id)
      else
        # Fallback: use first organization where user is a teammate
        user_org = actual_user.teammates.first&.organization
        if user_org
          company = user_org.company? ? user_org : user_org.root_company
          return scope.none unless company
          
          scope.where(deleted_at: nil, company_id: company.id)
        else
          scope.none
        end
      end
    end
  end

  private

  def user_is_teammate?
    return false unless user.respond_to?(:pundit_organization) && user.pundit_organization
    
    actual_user.teammates.exists?(organization: user.pundit_organization)
  end

  def user_is_teammate_of_company?
    return false unless user.respond_to?(:pundit_organization) && user.pundit_organization
    
    # Get the company (root organization)
    organization = user.pundit_organization
    company = organization.company? ? organization : organization.root_company
    return false unless company
    
    # Check if user is a teammate of the company or any organization within the company
    company_descendant_ids = company.self_and_descendants.pluck(:id)
    actual_user.teammates.exists?(organization_id: company_descendant_ids)
  end

  def user_is_creator?
    return false unless record&.creator
    
    actual_user == record.creator.person
  end

  def user_is_creator_or_owner?
    return false unless record
    
    # User is creator
    return true if user_is_creator?
    
    # User is owner (if owner is Teammate)
    if record.owner_type == 'Teammate'
      return true if record.owner.person == actual_user
    end
    
    # User is direct member of owner organization (if owner is Company/Department/Team)
    # Rails polymorphic associations use "Organization" as owner_type for STI subclasses
    if record.owner_type == 'Organization' || record.owner_type.in?(['Company', 'Department', 'Team'])
      return true if actual_user.teammates.exists?(organization: record.owner)
    end
    
    false
  end
end


