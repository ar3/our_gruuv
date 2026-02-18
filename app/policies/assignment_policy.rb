class AssignmentPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    return false unless viewing_teammate
    return false unless record&.company_id
    viewing_teammate.organization_id == record.company_id
  end

  def create?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with MAAP permissions can create assignments
    viewing_teammate.person.admin? || user_has_maap_permission?
  end

  def update?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with MAAP permissions can update assignments
    viewing_teammate.person.admin? || user_has_maap_permission_for_record?
  end

  def destroy?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with MAAP permissions can destroy assignments
    viewing_teammate.person.admin? || user_has_maap_permission_for_record?
  end

  def manage_consumer_assignments?
    return true if admin_bypass?
    return false unless viewing_teammate
    
    # Only admins or users with MAAP permissions can manage consumer assignments
    viewing_teammate.person.admin? || user_has_maap_permission_for_record?
  end

  def archive?
    update?
  end

  def restore?
    update?
  end

  private

  def user_has_maap_permission?
    return false unless viewing_teammate
    organization = record.company || actual_organization
    return false unless organization
    viewing_teammate.organization_id == organization.id && viewing_teammate.can_manage_maap?
  end

  # Teammates are attached to a single organization; assignment belongs to that org (company_id).
  def user_has_maap_permission_for_record?
    return false unless viewing_teammate
    return false unless record&.company_id
    viewing_teammate.organization_id == record.company_id && viewing_teammate.can_manage_maap?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      return scope.all if person.admin?
      return scope.none unless actual_organization
      scope.where(company: actual_organization)
    end
  end
end
