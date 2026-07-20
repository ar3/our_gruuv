# frozen_string_literal: true

module GoogleMeet
  # Lists recent Meet conferences the viewer organized that have a generated transcript.
  class ListTranscriptsService
    MAX_CONFERENCES = 25
    LOOKBACK_DAYS = 30

    Result = Struct.new(
      :conference_record_name,
      :transcript_name,
      :document_id,
      :export_uri,
      :start_time,
      :end_time,
      :display_name,
      keyword_init: true
    )

    def self.call(teammate:)
      new(teammate: teammate).call
    end

    def initialize(teammate:)
      @teammate = teammate
      @client = OauthClient.new(teammate)
    end

    def call
      return [] unless @client.authenticated?

      since = LOOKBACK_DAYS.days.ago.utc.iso8601
      filter = %(start_time > "#{since}")
      data = @client.get_json(
        "https://meet.googleapis.com/v2/conferenceRecords",
        params: { pageSize: MAX_CONFERENCES, filter: filter }
      )

      Array(data["conferenceRecords"]).flat_map { |conference| transcripts_for(conference) }
    end

    private

    def transcripts_for(conference)
      name = conference["name"].to_s
      return [] if name.blank?

      start_time = parse_time(conference["startTime"])
      end_time = parse_time(conference["endTime"])
      transcripts = @client.get_json(
        "https://meet.googleapis.com/v2/#{name}/transcripts",
        params: { pageSize: 10 }
      )

      Array(transcripts["transcripts"]).filter_map do |transcript|
        next unless transcript["state"].to_s == "FILE_GENERATED"

        docs = transcript["docsDestination"] || {}
        document_id = docs["document"].presence
        next if document_id.blank?

        Result.new(
          conference_record_name: name,
          transcript_name: transcript["name"],
          document_id: document_id,
          export_uri: docs["exportUri"],
          start_time: start_time,
          end_time: end_time,
          display_name: display_name_for(start_time)
        )
      end
    rescue OauthClient::ApiError => e
      Rails.logger.warn "GoogleMeet::ListTranscriptsService transcripts for #{name}: #{e.message}"
      []
    end

    def display_name_for(start_time)
      if start_time
        "Meet transcript · #{start_time.in_time_zone.strftime('%b %-d, %Y %-l:%M %p')}"
      else
        "Meet transcript"
      end
    end

    def parse_time(value)
      return nil if value.blank?

      Time.zone.parse(value.to_s)
    rescue ArgumentError
      nil
    end
  end
end
