# frozen_string_literal: true

module Goals
  # Returns candidate parent goals for a given child goal, per Phase 1 rules:
  # - Organization: company goals (owner_type Organization, privacy everyone_in_company)
  # - Department: company goals only
  # - Team: company, department, or team goals with privacy everyone_in_company
  # - CompanyTeammate: same-teammate goals OR org/dept/team goals with privacy everyone_in_company
  # Excludes completed and deleted; scoped by for_teammate so user only sees visible goals.
  class ParentCandidatesQuery
    def initialize(goal:, current_teammate:)
      @goal = goal
      @current_teammate = current_teammate
    end

    def call
      base_scope.where.not(id: @goal.id)
    end

    private

    def base_scope
      scope = Goal.for_teammate(@current_teammate)
                  .where(deleted_at: nil)
                  .where(completed_at: nil)

      case @goal.owner_type
      when 'Organization'
        scope.where(owner_type: 'Organization', privacy_level: 'everyone_in_company')
      when 'Department'
        scope.where(owner_type: 'Organization', privacy_level: 'everyone_in_company')
      when 'Team'
        scope.where(owner_type: ['Organization', 'Department', 'Team'], privacy_level: 'everyone_in_company')
      when 'CompanyTeammate'
        scope.where(
          "(owner_type = 'CompanyTeammate' AND owner_id = ?) OR (owner_type IN ('Organization', 'Department', 'Team') AND privacy_level = 'everyone_in_company')",
          @goal.owner_id
        )
      else
        scope.none
      end
    end
  end
end
