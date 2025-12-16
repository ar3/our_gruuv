class SearchPolicy < ApplicationPolicy
  def show?
    viewing_teammate.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope
    end
  end
end
