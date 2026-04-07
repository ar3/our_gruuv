# frozen_string_literal: true

module Goals
  # Candidate goals that can be linked to an Assignment, Ability, or Aspiration (same company, active draft).
  class AssociableGoalCandidatesQuery
    def initialize(associable:, goals_scope:)
      @associable = associable
      @goals_scope = goals_scope
    end

    def call
      return Goal.none unless @associable&.company_id

      @goals_scope
        .where(company_id: @associable.company_id)
        .where(deleted_at: nil)
        .where(completed_at: nil)
    end
  end
end
