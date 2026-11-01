# frozen_string_literal: true

module PossibleObservationSlackSearches
  # Per-search-run stats for the Search runs page.
  class RunStats
    Result = Data.define(
      :messages_consulted,
      :messages_already_memoized,
      :pogos_dismissed,
      :pogos_reviewing,
      :pogos_published,
      :messages_not_ogo_worthy
    )

    def self.call(search:)
      new(search: search).call
    end

    def initialize(search:)
      @search = search
    end

    def call
      rows = SlackPossibleObservation.where(
        "discovery_search_ids @> ?",
        [@search.id].to_json
      ).to_a

      dismissed = rows.count(&:dismissed?)
      open_rows = rows.reject(&:dismissed?)
      published = open_rows.count { |row| observation_exists?(row) }
      reviewing = open_rows.size - published

      consulted = @search.filtered_messages_count.positive? ? @search.filtered_messages_count : @search.messages_count
      memoized = @search.memo_hit_count.to_i
      # Messages that were processed but never became a candidate for this subject.
      not_worthy = [consulted - rows.size, 0].max

      Result.new(
        messages_consulted: consulted,
        messages_already_memoized: memoized,
        pogos_dismissed: dismissed,
        pogos_reviewing: [reviewing, 0].max,
        pogos_published: published,
        messages_not_ogo_worthy: not_worthy
      )
    end

    private

    def observation_exists?(row)
      DuplicateObservationsForMessage.call(
        organization: @search.organization,
        channel_id: row.channel_id,
        message_ts: row.message_ts
      ).exists?
    end
  end
end
