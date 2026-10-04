# frozen_string_literal: true

module MaapProposals
  class CreateSeatCreateDraft
    def self.call(organization:, proposer:, source: "in_product", payload: nil, source_markdown: nil, create_key: nil)
      new(
        organization: organization,
        proposer: proposer,
        source: source,
        payload: payload,
        source_markdown: source_markdown,
        create_key: create_key
      ).call
    end

    def initialize(organization:, proposer:, source:, payload:, source_markdown:, create_key:)
      @organization = organization
      @proposer = proposer
      @source = source
      @payload = payload
      @source_markdown = source_markdown
      @create_key = create_key.presence || SecureRandom.uuid
    end

    def call
      existing = MaapProposal.seat_creates
                             .open_proposals
                             .find_by(organization: @organization, create_key: @create_key)
      if existing
        return Result.err("An open create proposal already exists for this create_key") unless existing.editable?

        if @payload
          errors = @payload.validate!(company: @organization)
          return Result.err(errors) if errors.any?

          attrs = {
            proposed_payload: @payload.to_h,
            content_schema_version: SeatPayload::SCHEMA_VERSION,
            source: @source
          }
          attrs[:source_markdown] = @source_markdown unless @source_markdown.nil?
          return existing.update(attrs) ? Result.ok(existing) : Result.err(existing.errors.full_messages)
        end

        return Result.ok(existing)
      end

      payload = @payload || SeatPayload.blank_for_create(company: @organization)
      if payload.title_id.blank? &&
         payload.title_proposal_id.blank? &&
         payload.pending_title_name.blank?
        return Result.err(
          "Add at least one Title in this organization before proposing a Seat create, " \
          "or include a pending title / title proposal"
        )
      end

      errors = payload.validate!(company: @organization)
      return Result.err(errors) if errors.any?

      proposal = MaapProposal.new(
        organization: @organization,
        proposable: nil,
        proposable_type: "Seat",
        kind: "create",
        status: "draft",
        proposer: @proposer,
        create_key: @create_key,
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
