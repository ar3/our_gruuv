# frozen_string_literal: true

module MaapProposals
  class CreateAbilityEditDraft
    def self.call(ability:, proposer:, source: "in_product", payload: nil, source_markdown: nil)
      new(
        ability: ability,
        proposer: proposer,
        source: source,
        payload: payload,
        source_markdown: source_markdown
      ).call
    end

    def initialize(ability:, proposer:, source:, payload:, source_markdown:)
      @ability = ability
      @proposer = proposer
      @source = source
      @payload = payload
      @source_markdown = source_markdown
    end

    def call
      payload = @payload || AbilityPayload.from_ability(@ability)
      errors = payload.validate!(company: @ability.company)
      return Result.err(errors) if errors.any?

      proposal = MaapProposal.new(
        organization: @ability.company,
        proposable: @ability,
        kind: "edit",
        status: "draft",
        proposer: @proposer,
        based_on_semantic_version: @ability.semantic_version,
        source: @source,
        proposed_payload: payload.to_h,
        content_schema_version: AbilityPayload::SCHEMA_VERSION,
        source_markdown: @source_markdown
      )

      if proposal.save
        Result.ok(proposal)
      else
        Result.err(proposal.errors.full_messages)
      end
    end
  end
end
