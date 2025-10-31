class ObservationPolicy < ApplicationPolicy
  def index?
    actual_user.present?
  end

  def show?
    # Show page is only for the observer
    actual_user == record.observer
  end

  def new?
    create?
  end

  def create?
    actual_user.present?
  end

  def edit?
    update?
  end

  def update?
    actual_user == record.observer
  end

  def destroy?
    return true if admin_bypass?
    return true if actual_user == record.observer && record.created_at > 24.hours.ago
    false
  end

  def view_permalink?
    # Draft observations are only visible to their creator
    return false if record.draft? && actual_user != record.observer
    
    # Permalink page respects privacy settings
    case record.privacy_level
    when 'observer_only'
      actual_user == record.observer
    when 'observed_only'
      actual_user == record.observer || user_in_observees?
    when 'managers_only'
      actual_user == record.observer || user_in_management_hierarchy?
    when 'observed_and_managers'
      actual_user == record.observer || user_in_observees? || user_in_management_hierarchy? || user_can_manage_employment?
    when 'public_observation'
      true
    else
      false
    end
  end

  def view_negative_ratings?
    # Negative ratings have additional restrictions beyond privacy level
    return false unless view_permalink?
    
    actual_user == record.observer || 
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
    actual_user == record.observer
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
    # Observer, observed, and those with can_manage_employment can see change history
    actual_user == record.observer || 
    user_in_observees? || 
    user_can_manage_employment?
  end

  class Scope < Scope
    def resolve
      if user.respond_to?(:og_admin?) && user.og_admin?
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
    return false unless actual_user.is_a?(Person)
    
    record.observed_teammates.any? { |teammate| teammate.person == actual_user }
  end

  def user_in_management_hierarchy?
    return false unless actual_user.is_a?(Person)
    
    # Use record.company for organization context (KudosController doesn't have organization in pundit_user)
    organization = user.respond_to?(:pundit_organization) && user.pundit_organization ? user.pundit_organization : record.company
    
    record.observed_teammates.any? { |teammate| actual_user.in_managerial_hierarchy_of?(teammate.person, organization) }
  end

  def user_can_manage_employment?
    actual_user.respond_to?(:can_manage_employment?) && actual_user.can_manage_employment?(record.company)
  end
end
