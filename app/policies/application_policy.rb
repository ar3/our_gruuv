# frozen_string_literal: true

class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Admin bypass - og_admin users get all permissions
  def admin_bypass?
    actual_user&.admin?
  end

  # Helper method to get the actual user from pundit_user
  def actual_user
    user.respond_to?(:user) ? user.user : user
  end

  def index?
    admin_bypass? || false
  end

  def show?
    admin_bypass? || false
  end

  def create?
    admin_bypass? || false
  end

  def new?
    admin_bypass? || create?
  end

  def update?
    admin_bypass? || false
  end

  def edit?
    admin_bypass? || update?
  end

  def destroy?
    admin_bypass? || false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NoMethodError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope

    # Helper method to get the actual user from pundit_user
    def actual_user
      user.respond_to?(:user) ? user.user : user
    end
  end
end
