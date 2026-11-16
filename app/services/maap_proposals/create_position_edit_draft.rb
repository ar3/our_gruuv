# frozen_string_literal: true

module MaapProposals
  class CreatePositionEditDraft
    def self.call(position:, proposer:, source: "in_product", payload: nil)
      new(position: position, proposer: proposer, source: source, payload: payload).call
    end

    def initialize(position:, proposer:, source:, payload:)
      @position = position
      @proposer = proposer
      @source = source
      @payload = payload
    end

    def call
      payload = @payload || PositionPayload.from_position(@position)
      errors = payload.validate!(company: @position.company)
      return Result.err(errors) if errors.any?

      proposal = MaapProposal.new(
        organization: @position.company,
        proposable: @position,
        kind: "edit",
        status: "draft",
        proposer: @proposer,
        based_on_semantic_version: nil,
        source: @source,
        proposed_payload: payload.to_h,
        content_schema_version: PositionPayload::SCHEMA_VERSION
      )

      if proposal.save
        Result.ok(proposal)
      else
        Result.err(proposal.errors.full_messages)
      end
    end
  end
end
