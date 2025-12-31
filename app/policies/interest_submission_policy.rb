class InterestSubmissionPolicy < ApplicationPolicy
  def index?
    # Public access - anyone can view the index page
    true
  end

  def show?
    # Allow if user owns the submission or is admin
    return true if admin_bypass?
    return false unless viewing_teammate
    
    record.person == viewing_teammate.person
  end

  def new?
    # Public access - anyone can access the new form
    true
  end

  def create?
    # Public access - anyone can create submissions
    true
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      # Return only user's own submissions (or none if not logged in)
      return scope.none unless viewing_teammate
      
      person = viewing_teammate.person
      return scope.none unless person
      
      # Admins can see all, regular users see only their own
      if person.og_admin?
        scope.all
      else
        scope.by_person(person)
      end
    end
  end
end

