# frozen_string_literal: true

module Zoom
  # Lists recent Zoom cloud recordings the viewer hosted that include a transcript file.
  class ListTranscriptsService
    MAX_MEETINGS = 25
    LOOKBACK_DAYS = 30

    Result = Struct.new(
      :meeting_id,
      :meeting_uuid,
      :topic,
      :start_time,
      :download_url,
      :file_id,
      :file_type,
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

      from = LOOKBACK_DAYS.days.ago.to_date.iso8601
      to = Time.zone.today.iso8601
      data = @client.get_json(
        "/users/me/recordings",
        params: { from: from, to: to, page_size: MAX_MEETINGS }
      )

      Array(data["meetings"]).flat_map { |meeting| transcripts_for(meeting) }.first(MAX_MEETINGS)
    end

    private

    def transcripts_for(meeting)
      start_time = parse_time(meeting["start_time"])
      topic = meeting["topic"].presence || "Zoom meeting"
      Array(meeting["recording_files"]).filter_map do |file|
        next unless transcript_file?(file)
        next if file["download_url"].blank?

        Result.new(
          meeting_id: meeting["id"],
          meeting_uuid: meeting["uuid"],
          topic: topic,
          start_time: start_time,
          download_url: file["download_url"],
          file_id: file["id"],
          file_type: file["file_type"],
          display_name: display_name_for(topic, start_time)
        )
      end
    end

    def transcript_file?(file)
      file_type = file["file_type"].to_s.upcase
      recording_type = file["recording_type"].to_s.downcase
      file_type == "TRANSCRIPT" ||
        recording_type.include?("transcript") ||
        file["file_extension"].to_s.downcase == "vtt"
    end

    def display_name_for(topic, start_time)
      if start_time
        "#{topic} · #{start_time.in_time_zone.strftime('%b %-d, %Y %-l:%M %p')}"
      else
        topic
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
