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

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.admin?
        scope.all
      elsif can_manage_employment?
        # Users with employment management permission can see upload events for their organization
        scope.where(organization: actual_organization)
      else
        scope.none
      end
    end

    private

    def can_manage_employment?
      return false unless viewing_teammate
      organization = actual_organization
      return false unless organization
      
      person = viewing_teammate.person
      person&.can_manage_employment?(organization)
    end
  end

  private

  def can_manage_employment?
    return false unless viewing_teammate
    organization = actual_organization
    return false unless organization
    
    person = viewing_teammate.person
    person&.can_manage_employment?(organization)
  end
end
