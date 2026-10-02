# frozen_string_literal: true

module MaapProposals
  class UploadAbilityCreateMarkdown
    def self.call(organization:, proposer:, markdown:)
      new(organization: organization, proposer: proposer, markdown: markdown).call
    end

    def initialize(organization:, proposer:, markdown:)
      @organization = organization
      @proposer = proposer
      @markdown = markdown
    end

    def call
      result = AbilityMarkdownDeserializer.call(
        markdown: @markdown,
        organization: @organization
      )
      return result unless result.ok?

      if result.value[:kind] != "create"
        return Result.err("This markdown is an edit proposal; upload it from that ability's proposed edits")
      end

      CreateAbilityCreateDraft.call(
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
