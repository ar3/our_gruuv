# frozen_string_literal: true

module MaapProposals
  class CreateTitleEditDraft
    def self.call(title:, proposer:, source: "in_product", payload: nil)
      new(title: title, proposer: proposer, source: source, payload: payload).call
    end

    def initialize(title:, proposer:, source:, payload:)
      @title = title
      @proposer = proposer
      @source = source
      @payload = payload
    end

    def call
      payload = @payload || TitlePayload.from_title(@title)
      errors = payload.validate!(company: @title.company)
      return Result.err(errors) if errors.any?

      proposal = MaapProposal.new(
        organization: @title.company,
        proposable: @title,
        kind: "edit",
        status: "draft",
        proposer: @proposer,
        based_on_semantic_version: nil,
        source: @source,
        proposed_payload: payload.to_h,
        content_schema_version: TitlePayload::SCHEMA_VERSION
      )

      if proposal.save
        Result.ok(proposal)
      else
        Result.err(proposal.errors.full_messages)
      end
    end
  end
end
