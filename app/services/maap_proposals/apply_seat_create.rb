# frozen_string_literal: true

module MaapProposals
  class ApplySeatCreate
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
      return Result.err("Only Seat create proposals are supported") unless @proposal.seat_create?

      blockers = @proposal.seat_apply_blockers
      return Result.err(blockers) if blockers.any?

      payload = SeatPayload.from_hash(@proposal.proposed_payload)
      # Resolve linked title/team if proposals were applied after the draft was created.
      if payload.title_id.blank?
        applied_title = @proposal.children_for_role("title").find(&:applied?)&.proposable
        payload = SeatPayload.from_hash(payload.to_h.merge("title_id" => applied_title&.id)) if applied_title
      end
      if payload.team_id.blank?
        applied_team = @proposal.children_for_role("team").find(&:applied?)&.proposable
        payload = SeatPayload.from_hash(payload.to_h.merge("team_id" => applied_team&.id)) if applied_team
      end

      errors = payload.validate!(company: @proposal.organization, for_apply: true)
      return Result.err(errors) if errors.any?

      baseline_payload = SeatPayload.empty.to_h
      seat = Seat.new(state: :draft)

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
        SeatTitlesApplier.call(seat: seat, payload: payload)
        unless seat.save
          raise ApplyFailed.new(seat.errors.full_messages.presence || ["Failed to create seat"])
        end

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: nil,
          baseline_payload: baseline_payload,
          decision_warnings: [],
          proposable: seat.reload
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
