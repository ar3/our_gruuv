# frozen_string_literal: true

module MaapProposals
  class UpdateSeatEditDraft
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
      return Result.err("Only Seat proposals are supported") unless @proposal.proposable_type == "Seat"

      current = SeatPayload.from_hash(@proposal.proposed_payload).to_h
      merged = current.merge(@attributes.deep_stringify_keys.slice(*SeatPayload::ATTR_KEYS))
      payload = SeatPayload.from_hash(merged)

      errors = payload.validate!(company: @proposal.organization, excluding_seat: @proposal.proposable)
      return Result.err(errors) if errors.any?

      attrs = {
        proposed_payload: payload.to_h,
        content_schema_version: SeatPayload::SCHEMA_VERSION
      }
      attrs[:source_markdown] = @source_markdown unless @source_markdown.nil?

      if @proposal.update(attrs)
        Result.ok(@proposal)
      else
        Result.err(@proposal.errors.full_messages)
      end
    end
  end
end
