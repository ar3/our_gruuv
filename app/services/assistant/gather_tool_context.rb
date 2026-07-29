# frozen_string_literal: true

module Assistant
  # Invokes read-only AgentTools to pack context for Ask OG. No write tools.
  class GatherToolContext
    def self.call(context:, query:)
      new(context: context, query: query).call
    end

    def initialize(context:, query:)
      @context = context
      @query = query.to_s.strip
    end

    def call
      {
        search: invoke_data("search_organization", query: @query),
        teammates: invoke_data("list_teammates", query: @query, limit: 15),
        goals_needing_check_in: invoke_data("list_goals", needing_check_in: true, limit: 15),
        goals: invoke_data("list_goals", needing_check_in: false, limit: 15),
        goals_owned_by_me: invoke_data("list_goals", owned_by_me: true, limit: 15),
        goals_created_by_me: invoke_data("list_goals", created_by_me: true, limit: 15),
        sitemap: invoke_data("list_sitemap"),
        observations: invoke_data("list_observations", query: @query, limit: 10)
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
