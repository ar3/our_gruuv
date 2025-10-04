class UploadEventPolicy < ApplicationPolicy
  def index?
    admin_bypass? || can_manage_employment?
  end

  def show?
    admin_bypass? || can_manage_employment?
  end

  def create?
    admin_bypass? || can_manage_employment?
  end

  def new?
    admin_bypass? || can_manage_employment?
  end

  def destroy?
    admin_bypass? || can_manage_employment?
  end

  def process_upload?
    admin_bypass? || can_manage_employment?
  end

  class Scope < Scope
    def resolve
      if actual_user&.admin?
        scope.all
      elsif can_manage_employment?
        # Users with employment management permission can see upload events for their organization
        scope.where(organization: pundit_organization)
      else
        scope.none
      end
    end

    private

    def can_manage_employment?
      return false unless pundit_organization
      
      actual_user&.can_manage_employment?(pundit_organization)
    end

    def pundit_organization
      user.respond_to?(:pundit_organization) ? user.pundit_organization : nil
    end
  end

  private

  def can_manage_employment?
    return false unless pundit_organization
    
    actual_user&.can_manage_employment?(pundit_organization)
  end

  def pundit_organization
    user.respond_to?(:pundit_organization) ? user.pundit_organization : nil
  end
end
