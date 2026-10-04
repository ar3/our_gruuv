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

      if @proposal.seat_create?
        submit_create
      elsif @proposal.edit_kind? && @proposal.proposable_type == "Seat"
        submit_edit
      else
        Result.err("Only Seat proposals are supported")
      end
    end

    private

    def submit_create
      blockers = @proposal.seat_submit_blockers
      return Result.err(blockers) if blockers.any?

      payload = SeatPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      if @proposal.update(status: "submitted", submitted_at: Time.current)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end

    def submit_edit
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
