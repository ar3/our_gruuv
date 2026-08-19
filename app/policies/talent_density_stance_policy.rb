# frozen_string_literal: true

class TalentDensityStancePolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    return false if own_record?
    return false unless viewing_teammate.employed?
    return false unless same_company?

    access.can_edit?(record.company_teammate)
  end

  def update?
    show?
  end

  private

  def own_record?
    record.company_teammate_id == viewing_teammate.id
  end

  def same_company?
    record.company_id == viewing_teammate.organization_id
  end

  def access
    TalentDensity::Access.new(
      viewer: viewing_teammate,
      organization: viewing_teammate.organization,
      org_wide: org_wide_viewer?
    )
  end

  def org_wide_viewer?
    admin_bypass? || viewing_teammate.can_manage_employment?
  end
end
