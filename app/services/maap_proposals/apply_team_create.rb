# frozen_string_literal: true

module MaapProposals
  class ApplyTeamCreate
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
      return Result.err("Only Team create proposals are supported") unless @proposal.team_create?

      payload = TeamPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      team = nil
      ApplicationRecord.transaction do
        team = Team.new(
          company: @proposal.organization,
          name: payload.name,
          department_id: payload.department_id
        )
        unless team.save
          raise ApplyFailed, team.errors.full_messages
        end

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: nil,
          baseline_payload: {},
          decision_warnings: [],
          proposable: team
        )

        sync_parent_seat_payloads!(team)
      end

      Result.ok(@proposal.reload)
    rescue ApplyFailed => e
      Result.err(e.messages)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages)
    end

    private

    def sync_parent_seat_payloads!(team)
      @proposal.parent_proposal_links.where(role: "team").find_each do |link|
        seat_proposal = link.parent_proposal
        next unless seat_proposal.seat_create?
        next unless seat_proposal.open?

        payload = seat_proposal.proposed_payload.merge("team_id" => team.id)
        seat_proposal.update!(proposed_payload: payload)
      end
    end

    class ApplyFailed < StandardError
      attr_reader :messages

      def initialize(messages)
        @messages = Array(messages)
        super(@messages.join(", "))
      end
    end
  end
end
