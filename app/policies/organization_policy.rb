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

  def manage_departments_and_teams?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || viewing_teammate.can_manage_departments_and_teams?
  end

  def create?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    
    # Check type from record (for new records, type should be set from params)
    record_type = record.type.presence
    
    # For new records without a type, check if parent is a company (likely creating department/team)
    # For departments and teams, use the new permission
    if record_type == 'Department' || record_type == 'Team' || (record.new_record? && record.parent_id.present? && Organization.find_by(id: record.parent_id)&.company?)
      admin_bypass? || viewing_teammate.can_manage_departments_and_teams?
    else
      # For companies, use employment management permission
      admin_bypass? || viewing_teammate.can_manage_employment?
    end
  end

  def update?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    
    # For departments and teams, use the new permission
    if record.department? || record.team?
      admin_bypass? || viewing_teammate.can_manage_departments_and_teams?
    else
      # For companies, use employment management permission
      admin_bypass? || viewing_teammate.can_manage_employment?
    end
  end

  def archive?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    
    # For departments and teams, use the new permission
    if record.department? || record.team?
      admin_bypass? || viewing_teammate.can_manage_departments_and_teams?
    else
      # For companies, use employment management permission
      admin_bypass? || viewing_teammate.can_manage_employment?
    end
  end

  def destroy?
    # Destroy is disabled - use archive instead
    false
  end

  def check_ins_health?
    return false unless viewing_teammate
    return false unless record == viewing_teammate.organization
    admin_bypass? || viewing_teammate.can_manage_employment?
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

  def view_position_types?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || true
  end

  def view_prompt_templates?
    return false unless viewing_teammate
    return false unless organization_in_hierarchy?
    admin_bypass? || viewing_teammate.can_manage_prompts?
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
