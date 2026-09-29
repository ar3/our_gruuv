# frozen_string_literal: true

module MaapProposals
  class ApplyAssignmentCreate
    INITIAL_VERSION_TYPE = "early_draft"

    def self.call(proposal:, decided_by:, decision_note: nil)
      new(proposal: proposal, decided_by: decided_by, decision_note: decision_note).call
    end

    def initialize(proposal:, decided_by:, decision_note:)
      @proposal = proposal
      @decided_by = decided_by
      @decision_note = decision_note
      @warnings = []
    end

    def call
      return Result.err("Only submitted proposals can be applied") unless @proposal.decidable?
      return Result.err("Only Assignment create proposals are supported") unless @proposal.create_kind?

      payload = AssignmentPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      uniqueness = TitleUniqueness.call(
        organization: @proposal.organization,
        proposed_title: payload.title,
        mode: :create
      )
      title = uniqueness.apply_title
      @warnings << uniqueness.message if uniqueness.taken?

      baseline_payload = AssignmentPayload.empty.to_h

      assignment = Assignment.new(company: @proposal.organization)
      form = AssignmentForm.new(assignment)
      form.current_person = @decided_by.person
      form_attrs = {
        title: title,
        tagline: payload.tagline,
        required_activities: payload.required_activities,
        handbook: payload.handbook,
        department_id: payload.department_id,
        version_type: INITIAL_VERSION_TYPE
      }
      form.instance_variable_set(:@form_data_empty, false)
      return Result.err(form.errors.full_messages) unless form.validate(form_attrs)

      ApplicationRecord.transaction do
        unless form.save
          raise ApplyFailed.new(Array(form.errors.full_messages).presence || ["Failed to create assignment"])
        end

        assignment = assignment.reload
        @warnings.concat(
          AssignmentAssociationsApplier.new(assignment: assignment, payload: payload).call
        )

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: nil,
          baseline_payload: baseline_payload,
          decision_warnings: @warnings.compact,
          proposable: assignment
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
