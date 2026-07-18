# frozen_string_literal: true

class LlmInvocationPolicy < ApplicationPolicy
  def show?
    admin_bypass?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if admin_bypass?

      scope.none
    end
  end
end
