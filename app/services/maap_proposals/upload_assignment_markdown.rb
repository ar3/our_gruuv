# frozen_string_literal: true

module MaapProposals
  class UploadAssignmentMarkdown
    def self.call(assignment:, proposer:, markdown:)
      new(assignment: assignment, proposer: proposer, markdown: markdown).call
    end

    def initialize(assignment:, proposer:, markdown:)
      @assignment = assignment
      @proposer = proposer
      @markdown = markdown
    end

    def call
      result = AssignmentMarkdownDeserializer.call(markdown: @markdown, assignment: @assignment)
      return result unless result.ok?

      CreateAssignmentEditDraft.call(
        assignment: @assignment,
        proposer: @proposer,
        source: "markdown",
        payload: result.value[:payload],
        source_markdown: @markdown
      )
    end
  end
end
