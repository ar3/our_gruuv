# frozen_string_literal: true

module MaapProposals
  class SubmitSeatEdit
    def self.call(proposal:)
      new(proposal: proposal).call
    end

    def initialize(proposal:)
      @proposal = proposal
    end

    def call
      return Result.err("Only draft proposals can be submitted") unless @proposal.submittable?
      return Result.err("Only Seat edit proposals are supported") unless @proposal.edit_kind? && @proposal.proposable_type == "Seat"

      seat = @proposal.proposable
      payload = SeatPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: seat.company, excluding_seat: seat)
      return Result.err(errors) if errors.any?

      live = SeatPayload.from_seat(seat)
      return Result.err("Proposal has no changes from the current seat") if payload.same_as?(live)

      if @proposal.update(status: "submitted", submitted_at: Time.current)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
