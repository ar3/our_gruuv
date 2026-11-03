# frozen_string_literal: true

module CheckIns
  module SlackOgoConsult
    # Splits durable SlackPossibleObservations into object matches (≥75%) vs other.
    class DurableCandidateFilter
      Match = Data.define(:record)

      def self.call(subject:, viewer:, organization:, rateable_type:, rateable_id:, since: nil, until_time: nil)
        new(
          subject: subject,
          viewer: viewer,
          organization: organization,
          rateable_type: rateable_type,
          rateable_id: rateable_id,
          since: since,
          until_time: until_time
        ).call
      end

      def initialize(subject:, viewer:, organization:, rateable_type:, rateable_id:, since: nil, until_time: nil)
        @subject = subject
        @viewer = viewer
        @organization = organization
        @rateable_type = rateable_type.to_s
        @rateable_id = rateable_id.to_i
        @since = since
        @until = until_time
      end

      def call
        object_matches = []
        other_matches = []

        rows = PossibleObservationSlackSearches::VisibleSlackPossibleObservations.call(
          subject: @subject,
          viewer: @viewer,
          organization: @organization
        )

        rows.each do |row|
          moment = row.moment
          next if moment.confidence < CONFIDENCE_THRESHOLD
          next unless within_check_in_range?(moment)

          match = Match.new(record: moment)
          if object_match?(moment)
            object_matches << match
          else
            other_matches << match
          end
        end

        {
          object_matches: object_matches.sort_by { |m| -m.record.confidence },
          other_matches: other_matches.sort_by { |m| -m.record.confidence }
        }
      end

      private

      def within_check_in_range?(moment)
        return true if @since.blank?

        ts = moment.message_ts.to_s
        return true if ts.blank?

        at = Time.zone.at(ts.to_f)
        return false if at < @since
        return false if @until.present? && at > @until

        true
      end

      def object_match?(moment)
        payload = moment.payload_hash
        payload[:suggested_rateable_type].to_s == @rateable_type &&
          payload[:suggested_rateable_id].to_i == @rateable_id
      end
    end
  end
end

