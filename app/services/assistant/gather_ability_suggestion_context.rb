# frozen_string_literal: true

module Assistant
  # Read-only context pack for Abilities-focused MAAP Suggestion.
  class GatherAbilitySuggestionContext
    CATALOG_LIMIT = 50
    MATCH_LIMIT = 25

    def self.call(context:, query:, conversation_text: nil)
      new(context: context, query: query, conversation_text: conversation_text).call
    end

    def initialize(context:, query:, conversation_text: nil)
      @context = context
      @query = query.to_s.strip
    end

    def call
      {
        context_note:
          "Abilities focus: prefer edit of existing Abilities from the catalog. " \
          "Do not invent Seat/Assignment drafts in this focus.",
        suggestion_focus: MaapSuggestionFocus::ABILITIES,
        ability_catalog: invoke_data("list_abilities", limit: CATALOG_LIMIT, detail: "minimal"),
        abilities_matching_latest_message: invoke_data(
          "list_abilities",
          query: @query.presence,
          limit: MATCH_LIMIT,
          detail: "expensive"
        ),
        search: invoke_data(
          "search_organization",
          query: @query.presence || "ability milestone",
          detail: "expensive"
        )
      }
    end

    private

    def invoke_data(tool, **args)
      result = AgentTools::Registry.invoke(tool, context: @context, **args)
      result.ok? ? result.data : { error: result.error }
    end
  end
end
