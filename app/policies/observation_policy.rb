class ObservationPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    
    person = viewing_teammate.person
    
    # Observer is always allowed
    return true if person == record.observer
    
    # Check privacy level and apply appropriate rules
    case record.privacy_level
    when 'observer_only'
      # Only the observer (already checked above)
      false
    when 'observed_only'
      # Observer + observed person(s)
      user_in_observees?
    when 'managers_only'
      # Observer + managers of the observed
      user_in_management_hierarchy?
    when 'observed_and_managers'
      # Observer + observed + managers of the observed
      user_in_observees? || user_in_management_hierarchy?
    when 'public_to_company', 'public_to_world'
      # Observer + anyone with an active company teammate
      user_is_active_company_teammate?
    else
      false
    end
  end

  def new?
    create?
  end

  def create?
    viewing_teammate.present?
  end

  def edit?
    update?
  end

  def update?
    viewing_teammate.person == record.observer
  end

  def destroy?
    return true if admin_bypass?
    return true if viewing_teammate.person == record.observer && record.created_at > 24.hours.ago
    false
  end

  def view_permalink?
    # Draft observations are only visible to their creator
    return false if record.draft? && viewing_teammate && viewing_teammate.person != record.observer
    
    # Only public_to_world observations have permalink access (no auth required)
    # public_to_company observations are visible through authenticated pages only
    return true if record.privacy_level == 'public_to_world'
    
    # For other privacy levels, require authentication and check permissions
    return false unless viewing_teammate
    person = viewing_teammate.person
    
    # Permalink page respects privacy settings for internal levels
    case record.privacy_level
    when 'observer_only'
      person == record.observer
    when 'observed_only'
      person == record.observer || user_in_observees?
    when 'managers_only'
      person == record.observer || user_in_management_hierarchy?
    when 'observed_and_managers'
      person == record.observer || user_in_observees? || user_in_management_hierarchy? || user_can_manage_employment?
    when 'public_to_company'
      # public_to_company is visible to authenticated company members, but not via permalink
      false
    else
      false
    end
  end

  def view_negative_ratings?
    person = viewing_teammate.person
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
    viewing_teammate.person == record.observer
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

  def search?
    # Anyone who can create observations can search for GIFs
    create?
  end

  def view_change_history?
    person = viewing_teammate.person
    # Observer, observed, and those with can_manage_employment can see change history
    person == record.observer || 
    user_in_observees? || 
    user_can_manage_employment?
  end

  def publish?
    # Only the observer can publish, and only if the observation is a draft
    viewing_teammate.present? && viewing_teammate.person == record.observer && record.draft?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
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
    person = viewing_teammate.person
    record.observed_teammates.any? { |observed_teammate| observed_teammate.person == person }
  end

  def user_in_management_hierarchy?
    return false unless viewing_teammate
    return false unless viewing_teammate.is_a?(CompanyTeammate)
    return false unless record.company
    
    # Use the company from the observation
    company = record.company
    
    # Ensure viewing teammate is in the same company
    viewing_company_teammate = if viewing_teammate.organization == company
      viewing_teammate
    else
      CompanyTeammate.find_by(organization: company, person: viewing_teammate.person)
    end
    
    return false unless viewing_company_teammate
    
    # Get all observed teammates and check if viewing teammate is in management hierarchy of any
    record.observed_teammates.any? do |observed_teammate|
      # Skip if not a CompanyTeammate or not in the same company
      next false unless observed_teammate.is_a?(CompanyTeammate)
      next false unless observed_teammate.organization == company
      
      # Check if viewing teammate is in the managerial hierarchy of observed teammate
      viewing_company_teammate.in_managerial_hierarchy_of?(observed_teammate)
    end
  end

  def user_can_manage_employment?
    return false unless record.company
    Pundit.policy(pundit_user, record.company).manage_employment?
  end

  def user_is_active_company_teammate?
    return false unless viewing_teammate
    return false unless record.company
    
    viewing_teammate.person.active_teammates.exists?(organization: record.company)
  end
end
