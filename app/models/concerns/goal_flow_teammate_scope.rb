# frozen_string_literal: true

# Validates that a CompanyTeammate belongs to the same company as an MAAP catalog record
# (Assignment / Ability / Aspiration) when using the "goals for teammate" flow.
module GoalFlowTeammateScope
  module_function

  def teammate_matches_associable?(associable, company_teammate)
    return false unless associable && company_teammate
    return false unless company_teammate.is_a?(CompanyTeammate)

    company_teammate.organization_id == associable.company_id
  end
end
