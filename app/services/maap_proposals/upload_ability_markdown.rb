# frozen_string_literal: true

module MaapProposals
  class UploadAbilityMarkdown
    def self.call(ability:, proposer:, markdown:)
      new(ability: ability, proposer: proposer, markdown: markdown).call
    end

    def initialize(ability:, proposer:, markdown:)
      @ability = ability
      @proposer = proposer
      @markdown = markdown
    end

    def call
      result = AbilityMarkdownDeserializer.call(markdown: @markdown, ability: @ability)
      return result unless result.ok?

      CreateAbilityEditDraft.call(
        ability: @ability,
        proposer: @proposer,
        source: "markdown",
        payload: result.value[:payload],
        source_markdown: @markdown
      )
    end
  end
end
