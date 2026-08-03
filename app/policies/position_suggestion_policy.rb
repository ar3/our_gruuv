# frozen_string_literal: true

class PositionSuggestionPolicy < ApplicationPolicy
  def index?
    admin_bypass? || viewing_teammate.present?
  end

  def show?
    admin_bypass? || same_company?
  end

  def create?
    admin_bypass? || same_company?
  end

  def update?
    admin_bypass? || (same_company? && participant?)
  end

  def join?
    admin_bypass? || same_company?
  end

  def close?
    admin_bypass? || (same_company? && can_manage_maap?)
  end

  def create_comment?
    admin_bypass? || (same_company? && (participant? || record.open?))
  end

  def update_milestone?
    admin_bypass? || (same_company? && record.open? && (participant_active? || can_manage_maap?))
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate

      if viewing_teammate.person&.og_admin?
        scope.all
      else
        scope.where(organization_id: viewing_teammate.organization_id)
      end
    end
  end

  private

  def suggestion
    record.is_a?(PositionSuggestion) ? record : nil
  end

  def same_company?
    return false unless viewing_teammate && suggestion

    suggestion.organization_id == viewing_teammate.organization_id
  end

  def can_manage_maap?
    viewing_teammate&.can_manage_maap?
  end

  def participant?
    return false unless viewing_teammate && suggestion

    suggestion.participants.exists?(company_teammate_id: viewing_teammate.id)
  end

  def participant_active?
    return false unless viewing_teammate && suggestion

    suggestion.participants.active.exists?(company_teammate_id: viewing_teammate.id)
  end
end
