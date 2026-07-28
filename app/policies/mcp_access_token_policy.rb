# frozen_string_literal: true

class McpAccessTokenPolicy < ApplicationPolicy
  def index?
    viewing_teammate.present?
  end

  def create?
    viewing_teammate.present?
  end

  def destroy?
    return false unless viewing_teammate
    return true if admin_bypass?

    record.person_id == viewing_teammate.person_id
  end
end
