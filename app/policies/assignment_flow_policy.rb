# frozen_string_literal: true

class AssignmentFlowPolicy < ApplicationPolicy
  def show?
    return true if admin_bypass?
    return false unless viewing_teammate
    return false unless viewing_teammate.employed?
    record_in_organization_hierarchy?
  end

  def create?
    return true if admin_bypass?
    return false unless viewing_teammate
    return false unless viewing_teammate.employed?
    organization_in_hierarchy?
  end

  def update?
    return true if admin_bypass?
    return false unless viewing_teammate
    return false unless viewing_teammate.employed?
    record_in_organization_hierarchy?
  end

  def destroy?
    return true if admin_bypass?
    return false unless viewing_teammate
    return false unless viewing_teammate.employed?
    record_in_organization_hierarchy?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      return scope.none unless viewing_teammate.employed?
      return scope.all if viewing_teammate.person&.og_admin?

      company = actual_organization&.root_company || actual_organization
      return scope.none unless company

      scope.where(company_id: company.self_and_descendants.map(&:id))
    end
  end

  private

  def record_in_organization_hierarchy?
    return false unless record&.company
    viewing_teammate.organization.self_and_descendants.include?(record.company)
  end

  def organization_in_hierarchy?
    return false unless actual_organization
    viewing_teammate.organization.self_and_descendants.include?(
      actual_organization.root_company || actual_organization
    )
  end
end
