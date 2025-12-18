class ObservationPolicy < ApplicationPolicy
  def show?
    return false unless viewing_teammate
    
    person = viewing_teammate.person
    
    # Check if observer has an active teammate in the observation's company
    observer_has_active_teammate = person.active_teammates.exists?(organization: record.company)
    
    # If observer doesn't have an active teammate, only allow public_to_world published observations
    unless observer_has_active_teammate
      return record.published? && record.privacy_level == 'public_to_world'
    end
    
    # Draft observations: only the observer can see them (if they have active teammate)
    return false if record.draft? && person != record.observer
    
    # Observer is always allowed (for published observations, if they have active teammate)
    return true if person == record.observer
    
    # Journal (observer_only): only the observer can see them, even when published
    return false if record.privacy_level == 'observer_only'
    
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
    # Only published public_to_world observations have permalink access (no auth required)
    # public_to_company observations are visible through authenticated pages only
    return true if record.privacy_level == 'public_to_world' && record.published?
    false
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
        # Get company from viewing_teammate's organization
        company = viewing_teammate.organization
        return scope.none unless company
        
        # Use ObservationVisibilityQuery for complex visibility logic
        # This handles:
        # - Drafts: Only visible to observer
        # - Journal (observer_only): Only visible to observer
        # - Published: Follow privacy policy rules
        visibility_query = ObservationVisibilityQuery.new(person, company)
        visible_observations = visibility_query.visible_observations
        
        # Intersect with the incoming scope to preserve any existing filters
        # (e.g., if scope was already filtered by company or other conditions)
        scope.merge(visible_observations)
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
