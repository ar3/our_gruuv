# frozen_string_literal: true

module MaapProposals
  class CreateAssignmentEditDraft
    def self.call(assignment:, proposer:, source: "in_product", payload: nil, source_markdown: nil)
      new(
        assignment: assignment,
        proposer: proposer,
        source: source,
        payload: payload,
        source_markdown: source_markdown
      ).call
    end

    def initialize(assignment:, proposer:, source:, payload:, source_markdown:)
      @assignment = assignment
      @proposer = proposer
      @source = source
      @payload = payload
      @source_markdown = source_markdown
    end

    def call
      payload = @payload || AssignmentPayload.from_assignment(@assignment)
      errors = payload.validate!(company: @assignment.company)
      return Result.err(errors) if errors.any?

      proposal = MaapProposal.new(
        organization: @assignment.company,
        proposable: @assignment,
        kind: "edit",
        status: "draft",
        proposer: @proposer,
        based_on_semantic_version: @assignment.semantic_version,
        source: @source,
        proposed_payload: payload.to_h,
        content_schema_version: AssignmentPayload::SCHEMA_VERSION,
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
