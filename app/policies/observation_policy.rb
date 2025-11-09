class ObservationPolicy < ApplicationPolicy
  def index?
    teammate.present?
  end

  def show?
    # Show page is only for the observer
    teammate.person == record.observer
  end

  def new?
    create?
  end

  def create?
    teammate.present?
  end

  def edit?
    update?
  end

  def update?
    teammate.person == record.observer
  end

  def destroy?
    return true if admin_bypass?
    return true if teammate.person == record.observer && record.created_at > 24.hours.ago
    false
  end

  def view_permalink?
    return false unless teammate
    person = teammate.person
    # Draft observations are only visible to their creator
    return false if record.draft? && person != record.observer
    
    # Permalink page respects privacy settings
    case record.privacy_level
    when 'observer_only'
      person == record.observer
    when 'observed_only'
      person == record.observer || user_in_observees?
    when 'managers_only'
      person == record.observer || user_in_management_hierarchy?
    when 'observed_and_managers'
      person == record.observer || user_in_observees? || user_in_management_hierarchy? || user_can_manage_employment?
    when 'public_observation'
      true
    else
      false
    end
  end

  def view_negative_ratings?
    person = teammate.person
    # Negative ratings have additional restrictions beyond privacy level
    return false unless view_permalink?
    
    person == record.observer || 
    user_in_observees? || 
    user_in_management_hierarchy? || 
    user_can_manage_employment?
  end

  def post_message?
    # Anyone who can view the observation can post messages
    view_permalink?
  end

  def add_reaction?
    # Anyone who can view the observation/message can add reactions
    view_permalink?
  end

  def post_to_slack?
    # Only observer can post to Slack
    teammate.person == record.observer
  end

  def journal?
    index?
  end

  # Wizard actions - all require create permission
  def set_ratings?
    create?
  end

  def review?
    create?
  end

  def create_observation?
    create?
  end

  # Quick observation actions
  def quick_new?
    create?
  end

  def view_change_history?
    person = teammate.person
    # Observer, observed, and those with can_manage_employment can see change history
    person == record.observer || 
    user_in_observees? || 
    user_can_manage_employment?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless teammate
      person = teammate.person
      if person.og_admin?
        scope.all
      else
        # Use ObservationVisibilityQuery for complex visibility logic
        # We need to get the company from the context - this will be handled by the controller
        scope.none
      end
    end
  end

  private

  def user_in_observees?
    person = teammate.person
    record.observed_teammates.any? { |observed_teammate| observed_teammate.person == person }
  end

  def user_in_management_hierarchy?
    person = teammate.person
    
    # Use organization from teammate, fallback to record.company
    organization = actual_organization || record.company
    
    record.observed_teammates.any? { |observed_teammate| person.in_managerial_hierarchy_of?(observed_teammate.person, organization) }
  end

  def user_can_manage_employment?
    person = teammate.person
    person.can_manage_employment?(record.company)
  end
end
