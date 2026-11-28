# frozen_string_literal: true

class DocumentPolicy < ApplicationPolicy
  def index?
    return true if admin_bypass?
    return false unless viewing_teammate

    same_organization?
  end

  def show?
    return true if admin_bypass?
    return false unless viewing_teammate
    return false unless record&.organization_id

    same_organization_for_record?
  end

  def create?
    return true if admin_bypass?
    return false unless viewing_teammate

    # Any org teammate can create a document they will own/edit.
    same_organization?
  end

  def update?
    return true if admin_bypass?
    return false unless viewing_teammate
    return false unless record&.organization_id
    return false unless same_organization_for_record?

    clarity_library_admin? || owner_editor?
  end

  def destroy?
    update?
  end

  # MAAP managers (and owners/admins) may link/unlink Assignments without editing body.
  def manage_assignment_links?
    return true if admin_bypass?
    return false unless viewing_teammate
    return false unless record&.organization_id
    return false unless same_organization_for_record?

    clarity_library_admin? || owner_editor? || viewing_teammate.can_manage_maap?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate

      person = viewing_teammate.person
      return scope.all if person.admin? || person.og_admin?

      scope.where(organization_id: viewing_teammate.organization_id)
    end
  end

  private

  def record_organization
    return record if record.is_a?(Organization)
    return record.organization if record.respond_to?(:organization)

    actual_organization
  end

  def same_organization?
    organization = record_organization
    return false unless organization

    viewing_teammate.organization_id == organization.id
  end

  def same_organization_for_record?
    viewing_teammate.organization_id == record.organization_id
  end

  def clarity_library_admin?
    viewing_teammate.can_manage_clarity_library?
  end

  def owner_editor?
    owner = record.owner
    case owner
    when CompanyTeammate
      owner.id == viewing_teammate.id
    when Team
      owner.company_teammates.exists?(id: viewing_teammate.id)
    when Department, Organization
      # Group ownership at org/dept grain: Clarity Library Admins edit (and reassign).
      false
    else
      false
    end
  end
end
