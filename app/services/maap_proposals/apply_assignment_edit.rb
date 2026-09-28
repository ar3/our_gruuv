# frozen_string_literal: true

module MaapProposals
  class ApplyAssignmentEdit
    def self.call(proposal:, decided_by:, version_type:, decision_note: nil)
      new(
        proposal: proposal,
        decided_by: decided_by,
        version_type: version_type,
        decision_note: decision_note
      ).call
    end

    def initialize(proposal:, decided_by:, version_type:, decision_note:)
      @proposal = proposal
      @decided_by = decided_by
      @version_type = version_type.to_s
      @decision_note = decision_note
    end

    def call
      return Result.err("Only submitted proposals can be applied") unless @proposal.decidable?
      return Result.err("Only Assignment edit proposals are supported") unless @proposal.proposable_type == "Assignment"
      unless MaapProposal::VERSION_TYPES.include?(@version_type)
        return Result.err("version_type must be fundamental, clarifying, or insignificant")
      end

      assignment = @proposal.proposable
      payload = AssignmentPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: assignment.company)
      return Result.err(errors) if errors.any?

      baseline_payload = AssignmentPayload.from_assignment(assignment).to_h

      form = AssignmentForm.new(assignment)
      form.current_person = @decided_by.person
      form_attrs = {
        title: payload.title,
        tagline: payload.tagline,
        required_activities: payload.required_activities,
        handbook: payload.handbook,
        department_id: payload.department_id,
        version_type: @version_type
      }
      return Result.err(form.errors.full_messages) unless form.validate(form_attrs)

      ApplicationRecord.transaction do
        unless form.save
          raise ApplyFailed.new(Array(form.errors.full_messages).presence || ["Failed to save assignment"])
        end

        replace_outcomes!(assignment.reload, payload)

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: @version_type,
          baseline_payload: baseline_payload
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

    def replace_outcomes!(assignment, payload)
      keep_ids = []

      payload.outcomes.each do |outcome_attrs|
        description = outcome_attrs["description"]
        outcome_type = outcome_attrs["outcome_type"]
        existing = find_existing_outcome(assignment, outcome_attrs["id"])

        if existing
          existing.update!(description: description, outcome_type: outcome_type)
          keep_ids << existing.id
        else
          created = assignment.assignment_outcomes.create!(
            description: description,
            outcome_type: outcome_type
          )
          keep_ids << created.id
        end
      end

      assignment.assignment_outcomes.where.not(id: keep_ids).find_each(&:destroy!)
      assignment.refresh_outcomes_audit_snapshot_column!
    end

    def find_existing_outcome(assignment, raw_id)
      return nil if raw_id.blank?

      assignment.assignment_outcomes.find_by(id: raw_id.to_i)
    end
  end
end
