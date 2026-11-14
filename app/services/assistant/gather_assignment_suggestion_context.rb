# frozen_string_literal: true

module Assistant
  # Read-only context pack for Assignment-focused MAAP Suggestion.
  class GatherAssignmentSuggestionContext
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
          "Assignment focus: prefer edit of existing Assignments/Abilities from catalogs. " \
          "Do not invent Seat/Title/Position drafts in this focus.",
        suggestion_focus: MaapSuggestionFocus::ASSIGNMENT,
        assignment_catalog: invoke_data("list_assignments", limit: CATALOG_LIMIT, detail: "minimal"),
        assignments_matching_latest_message: invoke_data(
          "list_assignments",
          query: @query.presence,
          limit: MATCH_LIMIT,
          detail: "expensive"
        ),
        abilities: invoke_data(
          "list_abilities",
          query: @query.presence,
          limit: MATCH_LIMIT,
          detail: "expensive"
        ),
        search: invoke_data(
          "search_organization",
          query: @query.presence || "assignment ability",
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
