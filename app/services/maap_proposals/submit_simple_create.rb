# frozen_string_literal: true

module MaapProposals
  # Submit draft Title / Team / Position create proposals after payload validation.
  class SubmitSimpleCreate
    KIND_CHECKS = {
      "Title" => :title_create?,
      "Team" => :team_create?,
      "Position" => :position_create?
    }.freeze

    PAYLOADS = {
      "Title" => TitlePayload,
      "Team" => TeamPayload,
      "Position" => PositionPayload
    }.freeze

    def self.call(proposal:)
      new(proposal: proposal).call
    end

    def initialize(proposal:)
      @proposal = proposal
    end

    def call
      return Result.err("Only draft proposals can be submitted") unless @proposal.submittable?

      type = @proposal.proposable_type.to_s
      check = KIND_CHECKS[type]
      return Result.err("Unsupported create proposal type") if check.nil?
      return Result.err("Only #{type} create proposals are supported") unless @proposal.public_send(check)

      payload = PAYLOADS.fetch(type).from_hash(@proposal.proposed_payload)
      errors = if payload.respond_to?(:validate_for_apply!)
        # Position can be submitted while title is still a linked proposal.
        payload.validate!(company: @proposal.organization)
      else
        payload.validate!(company: @proposal.organization)
      end
      return Result.err(errors) if errors.any?

      if @proposal.update(status: "submitted", submitted_at: Time.current)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
