# frozen_string_literal: true

module AbilitiesHrReview
  # Heuristic (no LLM required) suggestion for join milestone_level from assignment text volume.
  class MilestoneProposer
    def self.call(assignment:)
      new(assignment: assignment).call
    end

    def initialize(assignment:)
      @assignment = assignment
    end

    def call
      return { 'level' => nil, 'rationale' => nil } unless @assignment

      combined = [
        @assignment.tagline,
        @assignment.handbook,
        @assignment.required_activities,
        outcomes_blob
      ].compact.join(' ')

      len = combined.length
      suggested =
        if len > 8_000
          3
        elsif len > 3_000
          2
        else
          nil
        end

      rationale =
        if suggested
          "Heuristic from assignment content length (~#{len} chars)."
        else
          nil
        end

      { 'level' => suggested, 'rationale' => rationale }
    end

    private

    def outcomes_blob
      return nil unless @assignment&.id

      AssignmentOutcome.where(assignment_id: @assignment.id).limit(100).pluck(:description).join(' ')
    end
  end
end
