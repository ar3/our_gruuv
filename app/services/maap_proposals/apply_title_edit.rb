# frozen_string_literal: true

module MaapProposals
  class ApplyTitleEdit
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
      return Result.err("Only Title edit proposals are supported") unless @proposal.edit_kind? && @proposal.proposable_type == "Title"

      title = @proposal.proposable
      payload = TitlePayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: title.company)
      return Result.err(errors) if errors.any?

      baseline_payload = TitlePayload.from_title(title).to_h

      ApplicationRecord.transaction do
        title.assign_attributes(
          external_title: payload.external_title,
          position_major_level_id: payload.position_major_level_id,
          department_id: payload.department_id,
          position_summary: payload.position_summary,
          alternative_titles: payload.alternative_titles
        )
        unless title.save
          raise ApplyFailed.new(title.errors.full_messages.presence || ["Failed to save title"])
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
