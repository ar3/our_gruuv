# frozen_string_literal: true

module MaapProposals
  class UpdateTitleEditDraft
    def self.call(proposal:, attributes: {})
      new(proposal: proposal, attributes: attributes).call
    end

    def initialize(proposal:, attributes:)
      @proposal = proposal
      @attributes = attributes
    end

    def call
      return Result.err("Only draft proposals can be edited") unless @proposal.editable?
      return Result.err("Only Title proposals are supported") unless @proposal.proposable_type == "Title"

      current = TitlePayload.from_hash(@proposal.proposed_payload).to_h
      attrs = @attributes.deep_stringify_keys
      merged = current.merge(attrs.slice(*TitlePayload::ATTR_KEYS))
      payload = TitlePayload.from_hash(merged)

      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      if @proposal.update(
        proposed_payload: payload.to_h,
        content_schema_version: TitlePayload::SCHEMA_VERSION
      )
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
