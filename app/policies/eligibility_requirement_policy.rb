class EligibilityRequirementPolicy < ApplicationPolicy
  def index?
    return false unless viewing_teammate
    return false if viewing_teammate.respond_to?(:terminated?) && viewing_teammate.terminated?
    return false if viewing_teammate.respond_to?(:last_terminated_at) && viewing_teammate.last_terminated_at.present?

    true
  end

  def show?
    index?
  end
end
