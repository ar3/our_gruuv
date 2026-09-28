# frozen_string_literal: true

module MaapProposals
  class RejectAssignmentEdit
    def self.call(proposal:, decided_by:, decision_note: nil)
      new(proposal: proposal, decided_by: decided_by, decision_note: decision_note).call
    end

    def initialize(proposal:, decided_by:, decision_note:)
      @proposal = proposal
      @decided_by = decided_by
      @decision_note = decision_note
    end

    def call
      return Result.err("Only submitted proposals can be rejected") unless @proposal.decidable?

      if @proposal.update(
        status: "rejected",
        decided_by: @decided_by,
        decided_at: Time.current,
        decision_note: @decision_note.presence
      )
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
