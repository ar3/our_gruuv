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

      if @proposal.create_kind?
        submit_create
      elsif @proposal.proposable_type == "Assignment"
        submit_edit
      else
        Result.err("Only Assignment proposals are supported")
      end
    end

    private

    def submit_create
      payload = AssignmentPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      if @proposal.update(status: "submitted", submitted_at: Time.current)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end

    def submit_edit
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
