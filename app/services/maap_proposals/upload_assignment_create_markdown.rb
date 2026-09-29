# frozen_string_literal: true

module MaapProposals
  class UploadAssignmentCreateMarkdown
    def self.call(organization:, proposer:, markdown:)
      new(organization: organization, proposer: proposer, markdown: markdown).call
    end

    def initialize(organization:, proposer:, markdown:)
      @organization = organization
      @proposer = proposer
      @markdown = markdown
    end

    def call
      result = AssignmentMarkdownDeserializer.call(
        markdown: @markdown,
        organization: @organization
      )
      return result unless result.ok?

      if result.value[:kind] != "create"
        return Result.err("This markdown is an edit proposal; upload it from that assignment's proposed edits")
      end

      CreateAssignmentCreateDraft.call(
        organization: @organization,
        proposer: @proposer,
        source: "markdown",
        payload: result.value[:payload],
        source_markdown: @markdown,
        create_key: result.value[:create_key]
      )
    end
  end
end
