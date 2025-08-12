class PersonPolicy < ApplicationPolicy
  def show?
    # Users can view their own profile, admins can view any profile
    user == record || user.admin?
  end

  def employment_summary?
    # Users can view their own employment summary, admins can view any
    user == record || user.admin?
  end

  def change?
    # Users can change their own employment, admins can change any
    user == record || user.admin?
  end

  def edit?
    # Users can only edit their own profile
    user == record
  end

  def update?
    # Users can only update their own profile
    user == record
  end

  def create?
    # Anyone can create a person (during join process)
    true
  end

  def index?
    # Only admins can see the people index
    user.admin?
  end

  def destroy?
    # Users cannot delete their own profile (for now)
    false
  end

  def connect_google_identity?
    # Users can connect Google accounts to their own profile
    user == record
  end

  def disconnect_identity?
    # Users can disconnect identities from their own profile
    user == record
  end

  class Scope < Scope
    def resolve
      # Users can only see themselves, admins can see all people
      if user.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end
end
