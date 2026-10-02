# frozen_string_literal: true

module MaapProposals
  class UpdateAbilityEditDraft
    def self.call(proposal:, attributes: {}, source_markdown: nil)
      new(proposal: proposal, attributes: attributes, source_markdown: source_markdown).call
    end

    def initialize(proposal:, attributes:, source_markdown:)
      @proposal = proposal
      @attributes = attributes
      @source_markdown = source_markdown
    end

    def call
      return Result.err("Only draft proposals can be edited") unless @proposal.editable?
      return Result.err("Only Ability proposals are supported") unless ability_proposal?

      current = AbilityPayload.from_hash(@proposal.proposed_payload).to_h
      merged = current.merge(@attributes.deep_stringify_keys.slice(*AbilityPayload::ATTR_KEYS))
      payload = AbilityPayload.from_hash(merged)

      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      attrs = {
        proposed_payload: payload.to_h,
        content_schema_version: AbilityPayload::SCHEMA_VERSION
      }
      attrs[:source_markdown] = @source_markdown unless @source_markdown.nil?

      if @proposal.update(attrs)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end

    private

    def ability_proposal?
      @proposal.proposable_type == "Ability"
    end
  end
end
