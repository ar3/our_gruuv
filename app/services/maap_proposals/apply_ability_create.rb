# frozen_string_literal: true

module MaapProposals
  class ApplyAbilityCreate
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
      return Result.err("Only Ability create proposals are supported") unless @proposal.ability_create?

      payload = AbilityPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      uniqueness = AbilityNameUniqueness.call(
        organization: @proposal.organization,
        proposed_name: payload.name,
        mode: :create
      )
      name = uniqueness.apply_name
      @warnings << uniqueness.message if uniqueness.taken?

      baseline_payload = AbilityPayload.empty.to_h

      ability = Ability.new(company: @proposal.organization)
      form = AbilityForm.new(ability)
      form.current_person = @decided_by.person
      form_attrs = {
        name: name,
        description: payload.description,
        company_id: @proposal.organization.id,
        department_id: payload.department_id,
        milestone_1_description: payload.milestone_1_description,
        milestone_2_description: payload.milestone_2_description,
        milestone_3_description: payload.milestone_3_description,
        milestone_4_description: payload.milestone_4_description,
        milestone_5_description: payload.milestone_5_description,
        version_type: INITIAL_VERSION_TYPE
      }
      form.instance_variable_set(:@form_data_empty, false)
      return Result.err(form.errors.full_messages) unless form.validate(form_attrs)

      ApplicationRecord.transaction do
        unless form.save
          raise ApplyFailed.new(Array(form.errors.full_messages).presence || ["Failed to create ability"])
        end

        @proposal.update!(
          status: "applied",
          decided_by: @decided_by,
          decided_at: Time.current,
          decision_note: @decision_note.presence,
          applied_version_type: nil,
          baseline_payload: baseline_payload,
          decision_warnings: @warnings.compact,
          proposable: ability.reload
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
