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

      baseline_payload = if @proposal.ability_create?
        AbilityPayload.empty.to_h
      elsif @proposal.create_kind?
        AssignmentPayload.empty.to_h
      elsif @proposal.proposable_type == "Assignment" && @proposal.proposable
        AssignmentPayload.from_assignment(@proposal.proposable).to_h
      elsif @proposal.proposable_type == "Ability" && @proposal.proposable
        AbilityPayload.from_ability(@proposal.proposable).to_h
      end

      if @proposal.update(
        status: "rejected",
        decided_by: @decided_by,
        decided_at: Time.current,
        decision_note: @decision_note.presence,
        baseline_payload: baseline_payload
      )
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
