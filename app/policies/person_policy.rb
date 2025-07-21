class PersonPolicy < ApplicationPolicy
  def show?
    # Users can only view their own profile
    user == record
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

  def destroy?
    # Users cannot delete their own profile (for now)
    false
  end

  class Scope < Scope
    def resolve
      # Users can only see themselves
      scope.where(id: user.id)
    end
  end
end
