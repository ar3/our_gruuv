# frozen_string_literal: true

module Goals
  # Returns candidate parent goals for a given child goal:
  # - Organization: company-owned goals with everyone_in_company only
  # - Department / Team: company, department, or team goals with everyone_in_company
  #   (never teammate-owned parents)
  # - CompanyTeammate: same-owner teammate goals where the viewer is creator OR the goal is
  #   everyone_in_company, plus company/dept/team goals with everyone_in_company
  # Incomplete (draft or started) and not deleted; scoped to the child's company.
  class ParentCandidatesQuery
    ORG_DEPT_TEAM = %w[Organization Department Team].freeze

    def initialize(goal:, current_teammate:)
      @goal = goal
      @current_teammate = current_teammate
    end

    def call
      base_scope.where.not(id: @goal.id)
    end

    private

    def base_scope
      scope = Goal.where(company_id: company_id).incomplete_unarchived

      case @goal.owner_type
      when 'Organization'
        scope.where(owner_type: 'Organization', privacy_level: 'everyone_in_company')
      when 'Department', 'Team'
        scope.where(owner_type: ORG_DEPT_TEAM, privacy_level: 'everyone_in_company')
      when 'CompanyTeammate'
        scope.where(
          <<~SQL.squish,
            (owner_type IN ('Organization', 'Department', 'Team') AND privacy_level = :company_visible)
            OR
            (
              owner_type = 'CompanyTeammate'
              AND owner_id = :owner_id
              AND (creator_id = :viewer_id OR privacy_level = :company_visible)
            )
          SQL
          company_visible: 'everyone_in_company',
          owner_id: @goal.owner_id,
          viewer_id: @current_teammate.id
        )
      else
        scope.none
      end
    end

    def company_id
      @goal.company_id.presence || @current_teammate.organization_id
    end
  end
end
