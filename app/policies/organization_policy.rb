class OrganizationPolicy < ApplicationPolicy
  def show?
    admin_bypass? || true # Anyone can view organization details
  end

  def manage_employment?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end
  
  def create_employment?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_create_employment?
  end

  def manage_maap?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_maap?
  end

  def manage_assignments?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_maap?
  end

  def view_feedback_requests?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def manage_departments_and_teams?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || viewing_teammate.can_manage_departments_and_teams?
  end

  def create?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?

    # Creating new organizations uses employment management permission
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def update?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?

    # Use employment management permission for organizations
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def archive?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?

    # Use employment management permission for organizations
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def destroy?
    # Destroy is disabled - use archive instead
    false
  end

  def check_ins_health?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    return false unless viewing_teammate.employed?
    admin_bypass? || organization_in_hierarchy?
  end

  def view_prompts?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_observations?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_seats?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    return false unless viewing_teammate.employed?
    admin_bypass? || true
  end

  def view_goals?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_abilities?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_assignments?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_aspirations?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_titles?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_prompt_templates?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    return false unless viewing_teammate.employed?
    admin_bypass? || true
  end

  def view_bulk_sync_events?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_search?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def download_company_teammates_csv?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def download_bulk_csv?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    return false unless viewing_teammate.employed?
    admin_bypass? || true
  end

  def view_bulk_download_history?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def download_any_bulk_download?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || viewing_teammate.can_manage_employment?
  end

  def download_own_bulk_download?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def customize_company?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || viewing_teammate.can_customize_company?
  end

  # Any active teammate in hierarchy can see the nav link to Slack settings (page access is separate).
  def view_slack_settings?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    return false unless viewing_teammate.employed?
    admin_bypass? || organization_in_hierarchy?
  end

  # Any active teammate in hierarchy can see the nav link to company preferences (edit page access is separate).
  def view_company_preferences?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    return false unless viewing_teammate.employed?
    admin_bypass? || true
  end

  private

  def organization_in_hierarchy?
    return false unless viewing_teammate
    teammate_org = viewing_teammate.organization
    return false unless teammate_org
    
    # For new records (not persisted), check if parent is in hierarchy
    if record.new_record?
      if record.parent_id.present?
        parent = Organization.find_by(id: record.parent_id)
        return false unless parent
        # Use ID comparison for reliability
        return parent.id == teammate_org.id || teammate_org.self_and_descendants.map(&:id).include?(parent.id)
      end
      # If no parent_id for new record, it's being created at root level - allow
      return true
    end
    
    # For persisted records, check if:
    # 1. Record is the teammate's organization
    # 2. Record is in teammate's organization hierarchy (descendant)
    # 3. Teammate's organization is in record's hierarchy (ancestor/descendant relationship)
    record.id == teammate_org.id || 
      teammate_org.self_and_descendants.map(&:id).include?(record.id) ||
      record.self_and_descendants.map(&:id).include?(teammate_org.id)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless viewing_teammate
      person = viewing_teammate.person
      if person&.admin?
        scope.all
      else
        scope.all # Organizations are generally viewable by all authenticated users
      end
    end
  end
end
