# frozen_string_literal: true

module MaapProposals
  class CreateTitleCreateDraft
    def self.call(organization:, proposer:, source: "in_product", payload: nil, create_key: nil)
      new(
        organization: organization,
        proposer: proposer,
        source: source,
        payload: payload,
        create_key: create_key
      ).call
    end

    def initialize(organization:, proposer:, source:, payload:, create_key:)
      @organization = organization
      @proposer = proposer
      @source = source
      @payload = payload
      @create_key = create_key.presence || SecureRandom.uuid
    end

    def call
      payload = @payload || TitlePayload.blank_for_create(company: @organization)
      errors = payload.validate!(company: @organization)
      return Result.err(errors) if errors.any?

      proposal = MaapProposal.new(
        organization: @organization,
        proposable: nil,
        proposable_type: "Title",
        kind: "create",
        status: "draft",
        proposer: @proposer,
        create_key: @create_key,
        based_on_semantic_version: nil,
        source: @source,
        proposed_payload: payload.to_h,
        content_schema_version: TitlePayload::SCHEMA_VERSION
      )

      proposal.save ? Result.ok(proposal) : Result.err(proposal.errors.full_messages)
    end
  end
end
