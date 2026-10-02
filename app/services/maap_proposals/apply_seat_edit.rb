# frozen_string_literal: true

module MaapProposals
  class ApplySeatEdit
    def self.call(proposal:, decided_by:, decision_note: nil)
      new(proposal: proposal, decided_by: decided_by, decision_note: decision_note).call
    end

    def initialize(proposal:, decided_by:, decision_note:)
      @proposal = proposal
      @decided_by = decided_by
      @decision_note = decision_note
    end

    def call
      return Result.err("Only submitted proposals can be applied") unless @proposal.decidable?
      return Result.err("Only Seat edit proposals are supported") unless @proposal.edit_kind? && @proposal.proposable_type == "Seat"

      seat = @proposal.proposable
      payload = SeatPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: seat.company, excluding_seat: seat)
      return Result.err(errors) if errors.any?

      baseline_payload = SeatPayload.from_seat(seat).to_h

      ApplicationRecord.transaction do
        seat.assign_attributes(
          title_id: payload.title_id,
          seat_needed_by: payload.seat_needed_by_date,
          job_classification: payload.job_classification,
          team_id: payload.team_id,
          reports_to_seat_id: payload.reports_to_seat_id,
          reports: payload.reports,
          seat_disclaimer: payload.seat_disclaimer,
          work_environment: payload.work_environment,
          physical_requirements: payload.physical_requirements,
          travel: payload.travel,
          why_needed: payload.why_needed,
          why_now: payload.why_now,
          costs_risks: payload.costs_risks
        )
        unless seat.save
          raise ApplyFailed.new(seat.errors.full_messages.presence || ["Failed to save seat"])
        end

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: nil,
          baseline_payload: baseline_payload,
          decision_warnings: []
        )
      end

      Result.ok(@proposal.reload)
    rescue ApplyFailed => e
      Result.err(e.messages)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages)
    end

    private

    class ApplyFailed < StandardError
      attr_reader :messages

      def initialize(messages)
        @messages = Array(messages)
        super(@messages.join(", "))
      end
    end
  end
end
