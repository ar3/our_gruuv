# frozen_string_literal: true

module MaapProposals
  class ApplyTitleCreate
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
      return Result.err("Only Title create proposals are supported") unless @proposal.title_create?

      payload = TitlePayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      title = nil
      ApplicationRecord.transaction do
        title = Title.new(
          company: @proposal.organization,
          external_title: payload.external_title,
          position_major_level_id: payload.position_major_level_id,
          department_id: payload.department_id,
          position_summary: payload.position_summary,
          alternative_titles: payload.alternative_titles
        )
        unless title.save
          raise ApplyFailed, title.errors.full_messages
        end

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: nil,
          baseline_payload: {},
          decision_warnings: [],
          proposable: title
        )

        # Leave Seat draft title_id unset so the proposer must associate it via edit.
        sync_child_position_payloads!(title)
      end

      Result.ok(@proposal.reload)
    rescue ApplyFailed => e
      Result.err(e.messages)
    rescue ActiveRecord::RecordInvalid => e
      Result.err(e.record.errors.full_messages)
    end

    private

    def sync_child_position_payloads!(title)
      @proposal.parent_proposals.select(&:seat_create?).each do |seat_proposal|
        seat_proposal.children_for_role("position").each do |position_proposal|
          next unless position_proposal.open?

          payload = position_proposal.proposed_payload.merge("title_id" => title.id)
          position_proposal.update!(proposed_payload: payload)
        end
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
