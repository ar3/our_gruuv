# frozen_string_literal: true

module MaapProposals
  class CreateSeatEditDraft
    def self.call(seat:, proposer:, source: "in_product", payload: nil, source_markdown: nil)
      new(
        seat: seat,
        proposer: proposer,
        source: source,
        payload: payload,
        source_markdown: source_markdown
      ).call
    end

    def initialize(seat:, proposer:, source:, payload:, source_markdown:)
      @seat = seat
      @proposer = proposer
      @source = source
      @payload = payload
      @source_markdown = source_markdown
    end

    def call
      payload = @payload || SeatPayload.from_seat(@seat)
      errors = payload.validate!(company: @seat.company, excluding_seat: @seat)
      return Result.err(errors) if errors.any?

      proposal = MaapProposal.new(
        organization: @seat.company,
        proposable: @seat,
        kind: "edit",
        status: "draft",
        proposer: @proposer,
        based_on_semantic_version: nil,
        source: @source,
        proposed_payload: payload.to_h,
        content_schema_version: SeatPayload::SCHEMA_VERSION,
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
