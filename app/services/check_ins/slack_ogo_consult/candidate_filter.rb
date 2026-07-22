# frozen_string_literal: true

module CheckIns
  module SlackOgoConsult
    # Splits batch extraction items into object matches (≥75%) vs other high-confidence hits.
    class CandidateFilter
      Match = Data.define(:item, :batch)

      def self.call(search:, rateable_type:, rateable_id:, since: nil, until_time: nil)
        new(search: search, rateable_type: rateable_type, rateable_id: rateable_id, since: since, until_time: until_time).call
      end

      def initialize(search:, rateable_type:, rateable_id:, since: nil, until_time: nil)
        @search = search
        @rateable_type = rateable_type.to_s
        @rateable_id = rateable_id.to_i
        @since = since
        @until = until_time
      end

      def call
        object_matches = []
        other_matches = []

        @search.message_batches.in_position_order.each do |batch|
          next unless batch.extraction_status == "completed"

          batch.extraction_items.each do |item|
            next if item[:confidence].to_f < CONFIDENCE_THRESHOLD
            # Once a candidate is promoted to an OGO it is represented by that observation
            # (draft shows on the 1-by-1 for its creator/observer; published shows for all).
            next if item[:observation_id].present?
            # Dismissed candidates are intentionally hidden from check-ins (state 2).
            next if item[:dismissed_at].present?
            # Scope to the current check-in window so surfaced candidates match the
            # observations list (published/draft OGOs are already timeframe-bounded).
            next unless within_check_in_range?(item)

            match = Match.new(item: item, batch: batch)
            if object_match?(item)
              object_matches << match
            else
              other_matches << match
            end
          end
        end

        {
          object_matches: object_matches.sort_by { |m| -m.item[:confidence].to_f },
          other_matches: other_matches.sort_by { |m| -m.item[:confidence].to_f }
        }
      end

      private

      # Slack ts is epoch seconds ("1710000000.000100"). Keep items with no parseable
      # timestamp (rare) so we never hide a real candidate on ambiguous data.
      def within_check_in_range?(item)
        return true if @since.blank?

        ts = item[:ts].to_s
        return true if ts.blank?

        moment = Time.zone.at(ts.to_f)
        return false if moment < @since
        return false if @until.present? && moment > @until

        true
      end

      def object_match?(item)
        item[:suggested_rateable_type].to_s == @rateable_type &&
          item[:suggested_rateable_id].to_i == @rateable_id
      end
    end
  end
end
