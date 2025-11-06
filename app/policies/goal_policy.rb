class GoalPolicy < ApplicationPolicy
  def index?
    admin_bypass? || user_is_teammate?
  end

  def show?
    admin_bypass? || record.can_be_viewed_by?(actual_user)
  end

  def create?
    admin_bypass? || user_is_teammate?
  end

  def update?
    admin_bypass? || user_is_creator_or_owner?
  end

  def destroy?
    admin_bypass? || user_is_creator?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if actual_user.og_admin?
        scope.all
      elsif user.respond_to?(:pundit_organization) && user.pundit_organization
        build_privacy_aware_scope(user.pundit_organization)
      else
        # Fallback: use first organization where user is a teammate
        user_org = actual_user.teammates.first&.organization
        if user_org
          build_privacy_aware_scope(user_org)
        else
          scope.none
        end
      end
    end
    
    private
    
    def build_privacy_aware_scope(organization)
      # Base scope - all goals in deleted state
      base_scope = scope.where(deleted_at: nil)
      
      # Build visibility conditions for each privacy level
      conditions = []
      params = []
      
      # Get organization context (company)
      company = organization.company? ? organization : organization.root_company
      return base_scope.none unless company
      
      # Get user's teammate IDs in the company
      user_teammate_ids = actual_user.teammates.where(organization: company).pluck(:id)
      
      # Always include goals where user is creator (regardless of privacy)
      # Get all teammate IDs where the person is the actual user
      creator_teammate_ids = Teammate.where(person_id: actual_user.id).pluck(:id)
      if creator_teammate_ids.any?
        conditions << "creator_id IN (?)"
        params << creator_teammate_ids
      end
      
      # Exclude goals with only_creator privacy from owner conditions
      # (they're only visible via creator check above)
      only_creator_exclusion = "privacy_level != ?"
      params_for_exclusion = ['only_creator']
      
      # only_creator: Only creator (already handled above)
      # No additional condition needed - creator check is sufficient
      # Note: Owners should NOT see goals with only_creator privacy (unless they're also the creator)
      
      # only_creator_and_owner: Creator + owner
      # For Person owner: check if user is owner (but NOT if privacy is only_creator)
      # This explicitly excludes only_creator privacy - owners can only see if privacy allows owner visibility
      conditions << "(#{only_creator_exclusion} AND privacy_level = ? AND owner_type = ? AND owner_id = ?)"
      params.concat(params_for_exclusion)
      params << 'only_creator_and_owner'
      params << 'Person'
      params << actual_user.id
      
      # For Organization owner: check if user belongs directly to owner organization
      user_organization_ids = actual_user.teammates.pluck(:organization_id).uniq
      if user_organization_ids.any?
        conditions << "(privacy_level = ? AND owner_type = ? AND owner_id IN (?))"
        params << 'only_creator_and_owner'
        params << 'Organization'
        params << user_organization_ids
      end
      
      # Note: only_creator privacy level is handled by creator check above
      # Owners should NOT see goals with only_creator privacy (unless they are also the creator)
      
      # only_creator_owner_and_managers: Creator + owner + managers
      # For Person owner: check if user is owner or manager of owner
      conditions << "(#{only_creator_exclusion} AND privacy_level = ? AND owner_type = ? AND owner_id = ?)"
      params.concat(params_for_exclusion)
      params << 'only_creator_owner_and_managers'
      params << 'Person'
      params << actual_user.id
      
      # For Person owner: check if user is manager of owner
      managed_person_ids = managed_person_ids_for_user(company)
      if managed_person_ids.any?
        conditions << "(privacy_level = ? AND owner_type = ? AND owner_id IN (?))"
        params << 'only_creator_owner_and_managers'
        params << 'Person'
        params << managed_person_ids
      end
      
      # For Organization owner: check if user belongs directly to owner organization
      user_organization_ids = actual_user.teammates.pluck(:organization_id).uniq
      if user_organization_ids.any?
        conditions << "(privacy_level = ? AND owner_type = ? AND owner_id IN (?))"
        params << 'only_creator_owner_and_managers'
        params << 'Organization'
        params << user_organization_ids
      end
      
      # For Organization owner: check if user manages anyone who belongs directly to owner organization
      if managed_person_ids.any?
        managed_org_ids = Teammate.where(person_id: managed_person_ids).pluck(:organization_id).uniq
        if managed_org_ids.any?
          conditions << "(privacy_level = ? AND owner_type = ? AND owner_id IN (?))"
          params << 'only_creator_owner_and_managers'
          params << 'Organization'
          params << managed_org_ids
        end
      end
      
      # everyone_in_company: Anyone in the company
      # Check if user is a teammate in the company (not just if they have teammate IDs)
      if actual_user.teammates.exists?(organization: company)
        # For Person owner: check if owner has a teammate in the company
        # This should include all Person owners who have teammates in the company
        company_person_ids = Teammate.where(organization: company).pluck(:person_id).uniq
        if company_person_ids.any?
          conditions << "(privacy_level = ? AND owner_type = ? AND owner_id IN (?))"
          params << 'everyone_in_company'
          params << 'Person'
          params << company_person_ids
        end
        
        # For Organization owner: check if owner resolves to the same company
        # Get all organization IDs that resolve to this company (company itself + all descendants)
        org_ids = company.self_and_descendants.map(&:id)
        if org_ids.any?
          conditions << "(privacy_level = ? AND owner_type = ? AND owner_id IN (?))"
          params << 'everyone_in_company'
          params << 'Organization'
          params << org_ids
        end
      end
      
      # Combine all conditions with OR
      if conditions.empty?
        return base_scope.none
      end
      
      # Build the query using where with OR conditions
      # Rails handles array parameters correctly when using where with hash syntax
      # For raw SQL with arrays, we need to expand them properly
      query = base_scope
      param_index = 0
      conditions.each_with_index do |condition, index|
        # Count placeholders in this condition
        placeholder_count = condition.count('?')
        condition_params = params[param_index, placeholder_count]
        param_index += placeholder_count
        
        # Expand arrays in IN clauses for proper SQL generation
        expanded_params = condition_params.map do |param|
          if param.is_a?(Array)
            # For IN clauses, expand the array and create individual placeholders
            param.map { |p| p }
          else
            param
          end
        end.flatten
        
        # If condition has arrays, we need to adjust placeholders
        if condition_params.any? { |p| p.is_a?(Array) }
          # Replace IN (?) with IN (?, ?, ...) for arrays
          adjusted_condition = condition.dup
          condition_params.each_with_index do |param, p_idx|
            if param.is_a?(Array)
              placeholders = param.map { '?' }.join(', ')
              adjusted_condition.sub!('IN (?)', "IN (#{placeholders})")
            end
          end
          condition = adjusted_condition
        end
        
        if index == 0
          query = query.where(condition, *expanded_params)
        else
          query = query.or(base_scope.where(condition, *expanded_params))
        end
      end
      
      query
    end
    
    def managed_person_ids_for_user(company)
      # Get all person IDs that this user manages in the company
      EmploymentTenure.active
                     .where(company: company, manager: actual_user)
                     .joins(:teammate)
                     .pluck('teammates.person_id')
                     .uniq
    end
  end

  private

  def user_is_teammate?
    return false unless user.respond_to?(:pundit_organization) && user.pundit_organization
    
    actual_user.teammates.exists?(organization: user.pundit_organization)
  end

  def user_is_creator?
    return false unless record&.creator
    
    actual_user == record.creator.person
  end

  def user_is_creator_or_owner?
    return false unless record
    
    # User is creator
    return true if user_is_creator?
    
    # User is owner (if owner is Person)
    if record.owner_type == 'Person' && record.owner_id == actual_user.id
      return true
    end
    
    # User is direct member of owner organization (if owner is Organization)
    if record.owner_type == 'Organization'
      return true if actual_user.teammates.exists?(organization: record.owner)
    end
    
    false
  end
end


