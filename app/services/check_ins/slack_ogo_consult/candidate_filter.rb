# frozen_string_literal: true

module CheckIns
  module SlackOgoConsult
    # Splits batch extraction items into object matches (≥80%) vs other high-confidence hits.
    class CandidateFilter
      Match = Data.define(:item, :batch)

      def self.call(search:, rateable_type:, rateable_id:)
        new(search: search, rateable_type: rateable_type, rateable_id: rateable_id).call
      end

      def initialize(search:, rateable_type:, rateable_id:)
        @search = search
        @rateable_type = rateable_type.to_s
        @rateable_id = rateable_id.to_i
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

      def object_match?(item)
        item[:suggested_rateable_type].to_s == @rateable_type &&
          item[:suggested_rateable_id].to_i == @rateable_id
      end
    end
  end
end
