# frozen_string_literal: true

module Assistant
  # Read-only AgentTools context pack focused on Seat / MAAP suggestion.
  class GatherSeatSuggestionContext
    def self.call(context:, query:)
      new(context: context, query: query).call
    end

    def initialize(context:, query:)
      @context = context
      @query = query.to_s.strip
    end

    def call
      {
        search: invoke_data("search_organization", query: @query.presence || "seat title assignment", detail: "expensive"),
        titles: invoke_data("list_titles", query: @query, limit: 25, detail: "expensive"),
        positions: invoke_data("list_positions", query: @query, limit: 25, detail: "expensive"),
        assignments: invoke_data("list_assignments", query: @query, limit: 25, detail: "expensive"),
        abilities: invoke_data("list_abilities", query: @query, limit: 25, detail: "expensive"),
        sitemap_seat_pages: {
          seat_suggestion: "This chat",
          proposed_seat_creates: "Proposed Seat creates list after Confirm"
        }
      }
    end

    private

    def invoke_data(name, **args)
      result = AgentTools::Registry.invoke(name, context: @context, **args)
      if result.ok?
        result.data
      else
        { error: result.error }
      end
    end
  end
end
