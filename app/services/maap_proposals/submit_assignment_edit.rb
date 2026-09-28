# frozen_string_literal: true

module MaapProposals
  class SubmitAssignmentEdit
    def self.call(proposal:)
      new(proposal: proposal).call
    end

    def initialize(proposal:)
      @proposal = proposal
    end

    def call
      return Result.err("Only draft proposals can be submitted") unless @proposal.submittable?
      return Result.err("Only Assignment edit proposals are supported") unless @proposal.proposable_type == "Assignment"

      assignment = @proposal.proposable
      payload = AssignmentPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: assignment.company)
      return Result.err(errors) if errors.any?

      live = AssignmentPayload.from_assignment(assignment)
      return Result.err("Proposal has no changes from the current assignment") if payload.same_as?(live)

      if @proposal.update(status: "submitted", submitted_at: Time.current)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
