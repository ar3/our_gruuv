# frozen_string_literal: true

module Goals
  # Returns candidate child goals for a given parent goal, per Phase 2 rules:
  # - CompanyTeammate: not completed, same teammate owner
  # - Organization / Department / Team: not completed, privacy_level everyone_in_company
  # Excludes completed and deleted; scoped by for_teammate so user only sees visible goals.
  class ChildCandidatesQuery
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
      when 'CompanyTeammate'
        scope.owned_by_teammate.where(owner_id: @goal.owner_id)
      when 'Organization', 'Department', 'Team'
        scope.where(privacy_level: 'everyone_in_company')
      else
        scope.none
      end
    end
  end
end
