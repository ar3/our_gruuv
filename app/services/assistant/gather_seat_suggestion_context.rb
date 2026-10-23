# frozen_string_literal: true

module Assistant
  # Read-only AgentTools context pack focused on Seat / MAAP suggestion.
  # Prioritizes the org Assignment catalog and Assignments already on similar
  # Titles/Positions so the model can reuse them instead of asking the user to restate.
  class GatherSeatSuggestionContext
    CATALOG_LIMIT = 50
    MATCH_LIMIT = 25
    RELATED_POSITION_LIMIT = 8
    MIN_TITLE_MATCH_LENGTH = 4

    def self.call(context:, query:, conversation_text: nil)
      new(context: context, query: query, conversation_text: conversation_text).call
    end

    def initialize(context:, query:, conversation_text: nil)
      @context = context
      @query = query.to_s.strip
      @conversation_text = conversation_text.to_s
    end

    def call
      corpus = [@query, @conversation_text].reject(&:blank?).join("\n")
      title_catalog = invoke_data("list_titles", limit: CATALOG_LIMIT, detail: "minimal")
      mentioned_titles = titles_mentioned_in(corpus, title_catalog)

      positions_matching_query = invoke_data(
        "list_positions",
        query: @query.presence,
        limit: MATCH_LIMIT,
        detail: "expensive"
      )
      positions_for_mentioned_titles = mentioned_titles.filter_map do |title_row|
        path = title_row[:path] || title_row["path"]
        next if path.blank?

        invoke_data(
          "list_positions",
          title_path: path,
          limit: 10,
          detail: "expensive"
        )
      end

      referenced_positions = hydrate_referenced_positions(
        positions_matching_query,
        *positions_for_mentioned_titles
      )

      {
        context_note:
          "Prefer existing Assignments from assignment_catalog and from " \
          "referenced_positions_with_assignments. When the user points at a Title/Position " \
          "already in this pack, use that Position's Assignments — do not ask them to restate.",
        assignment_catalog: invoke_data(
          "list_assignments",
          limit: CATALOG_LIMIT,
          detail: "minimal"
        ),
        assignments_matching_latest_message: invoke_data(
          "list_assignments",
          query: @query.presence,
          limit: MATCH_LIMIT,
          detail: "expensive"
        ),
        titles_matching_latest_message: invoke_data(
          "list_titles",
          query: @query.presence,
          limit: MATCH_LIMIT,
          detail: "expensive"
        ),
        titles_mentioned_in_conversation: mentioned_titles,
        positions_matching_latest_message: positions_matching_query,
        referenced_positions_with_assignments: referenced_positions,
        abilities: invoke_data(
          "list_abilities",
          query: @query.presence,
          limit: MATCH_LIMIT,
          detail: "expensive"
        ),
        search: invoke_data(
          "search_organization",
          query: @query.presence || "seat title assignment position",
          detail: "expensive"
        ),
        sitemap_seat_pages: {
          seat_suggestion: "This chat",
          proposed_seat_creates: "Proposed Seat creates list after Confirm"
        }
      }
    end

    private

    def titles_mentioned_in(corpus, title_catalog)
      rows = Array(title_catalog.is_a?(Hash) ? (title_catalog[:titles] || title_catalog["titles"]) : nil)
      text = corpus.downcase
      return [] if text.blank? || rows.empty?

      rows.filter_map do |row|
        name = (row[:title] || row["title"] || row[:external_title] || row["external_title"]).to_s.strip
        path = row[:path] || row["path"]
        next if name.length < MIN_TITLE_MATCH_LENGTH
        next unless text.include?(name.downcase)

        { title: name, path: path }
      end.uniq { |row| row[:path].presence || row[:title] }
    end

    def hydrate_referenced_positions(*position_payloads)
      paths = position_payloads.flat_map { |payload| position_paths_from(payload) }.uniq.first(RELATED_POSITION_LIMIT)
      paths.filter_map do |path|
        data = invoke_data("get_position", path: path)
        next if data[:error] || data["error"]

        data[:position] || data["position"] || data
      end
    end

    def position_paths_from(payload)
      return [] if payload.blank? || payload[:error] || payload["error"]

      rows = payload[:positions] || payload["positions"] || []
      Array(rows).filter_map { |row| row[:path] || row["path"] }
    end

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
