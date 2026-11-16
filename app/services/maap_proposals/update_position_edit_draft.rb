# frozen_string_literal: true

module MaapProposals
  class UpdatePositionEditDraft
    def self.call(proposal:, attributes: {})
      new(proposal: proposal, attributes: attributes).call
    end

    def initialize(proposal:, attributes:)
      @proposal = proposal
      @attributes = attributes
    end

    def call
      return Result.err("Only draft proposals can be edited") unless @proposal.editable?
      return Result.err("Only Position proposals are supported") unless @proposal.proposable_type == "Position"

      current = PositionPayload.from_hash(@proposal.proposed_payload).to_h
      attrs = @attributes.deep_stringify_keys
      if attrs.key?("assignment_links")
        attrs["assignment_links"] = PositionPayload.normalize_assignment_links(attrs["assignment_links"])
      end
      # Edits keep the live position's title; do not retarget to another Title
      attrs["title_id"] = @proposal.proposable.title_id
      attrs.delete("title_proposal_id")

      merged = current.merge(attrs.slice(*PositionPayload::ATTR_KEYS))
      payload = PositionPayload.from_hash(merged)

      errors = payload.validate!(company: @proposal.organization)
      return Result.err(errors) if errors.any?

      if @proposal.update(
        proposed_payload: payload.to_h,
        content_schema_version: PositionPayload::SCHEMA_VERSION
      )
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
