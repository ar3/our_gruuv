# frozen_string_literal: true

module MaapProposals
  class ApplyAbilityEdit
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
      return Result.err("Only Ability edit proposals are supported") unless @proposal.edit_kind? && @proposal.proposable_type == "Ability"
      unless MaapProposal::VERSION_TYPES.include?(@version_type)
        return Result.err("version_type must be fundamental, clarifying, or insignificant")
      end

      ability = @proposal.proposable
      payload = AbilityPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: ability.company)
      return Result.err(errors) if errors.any?

      baseline_payload = AbilityPayload.from_ability(ability).to_h

      form = AbilityForm.new(ability)
      form.current_person = @decided_by.person
      form_attrs = {
        name: payload.name,
        description: payload.description,
        company_id: ability.company_id,
        department_id: payload.department_id,
        milestone_1_description: payload.milestone_1_description,
        milestone_2_description: payload.milestone_2_description,
        milestone_3_description: payload.milestone_3_description,
        milestone_4_description: payload.milestone_4_description,
        milestone_5_description: payload.milestone_5_description,
        version_type: @version_type
      }
      form.instance_variable_set(:@form_data_empty, false)
      return Result.err(form.errors.full_messages) unless form.validate(form_attrs)

      ApplicationRecord.transaction do
        unless form.save
          raise ApplyFailed.new(Array(form.errors.full_messages).presence || ["Failed to save ability"])
        end

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: @version_type,
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
