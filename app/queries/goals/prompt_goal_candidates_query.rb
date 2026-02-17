# frozen_string_literal: true

module Goals
  # Returns candidate goals that can be associated with a prompt (Growth Plan).
  # Per Phase 3: not completed, owned by the same teammate as the prompt's company_teammate.
  class PromptGoalCandidatesQuery
    def initialize(prompt:)
      @prompt = prompt
    end

    def call
      return Goal.none unless @prompt.company_teammate_id.present?

      Goal.owned_by_teammate
          .where(owner_id: @prompt.company_teammate_id)
          .where(company_id: company_id)
          .where(deleted_at: nil)
          .where(completed_at: nil)
    end

    private

    def company_id
      @prompt.company_teammate.organization.root_company&.id || @prompt.company_teammate.organization_id
    end
  end
end
