# frozen_string_literal: true

module MaapProposals
  class SubmitAbilityEdit
    def self.call(proposal:)
      new(proposal: proposal).call
    end

    def initialize(proposal:)
      @proposal = proposal
    end

    def call
      return Result.err("Only draft proposals can be submitted") unless @proposal.submittable?

      if @proposal.ability_create?
        submit_create
      elsif @proposal.edit_kind? && @proposal.proposable_type == "Ability"
        submit_edit
      else
        Result.err("Only Ability proposals are supported")
      end
    end

    private

    def submit_create
      payload = AbilityPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      if @proposal.update(status: "submitted", submitted_at: Time.current)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end

    def submit_edit
      ability = @proposal.proposable
      payload = AbilityPayload.from_hash(@proposal.proposed_payload)
      errors = payload.validate!(company: ability.company)
      return Result.err(errors) if errors.any?

      live = AbilityPayload.from_ability(ability)
      return Result.err("Proposal has no changes from the current ability") if payload.same_as?(live)

      if @proposal.update(status: "submitted", submitted_at: Time.current)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
