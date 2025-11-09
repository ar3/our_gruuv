class SearchPolicy < ApplicationPolicy
  def show?
    teammate.present?
  end

  def index?
    teammate.present?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope
    end
  end
end
