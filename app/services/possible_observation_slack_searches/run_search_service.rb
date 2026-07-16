# frozen_string_literal: true

module PossibleObservationSlackSearches
  class RunSearchService
    Result = Struct.new(:success?, :error, keyword_init: true)

    def self.call(...) = new(...).call

    def initialize(search:)
      @search = search
      @creator = search.creator_company_teammate
      @subject = search.subject_company_teammate
    end

    def call
      token = creator.slack_search_identity&.raw_credentials&.dig("token")
      if token.blank?
        search.mark_search_failed!("Slack (search) is not connected for the creator.")
        return Result.new(success?: false, error: search.search_error)
      end

      search.mark_search_processing!
      query = build_query
      response = HTTP.auth("Bearer #{token}")
                     .get(
                       "https://slack.com/api/search.messages",
                       params: {
                         query: query,
                         count: PossibleObservationSlackSearch::MAX_MESSAGES,
                         sort: "timestamp",
                         sort_dir: "desc",
                         highlight: false
                       }
                     )
      data = JSON.parse(response.body.to_s)

      unless data["ok"]
        search.mark_search_failed!("Slack search failed: #{data['error'] || 'unknown error'}")
        return Result.new(success?: false, error: search.search_error)
      end

      messages = normalize_messages(data.dig("messages", "matches") || [])
      raw_results = {
        "version" => PossibleObservationSlackSearch::RAW_RESULTS_VERSION,
        "query" => query,
        "window_days" => search.window_days,
        "fetched_at" => Time.current.iso8601,
        "total" => data.dig("messages", "total"),
        "paging" => data.dig("messages", "paging"),
        "messages" => messages
      }

      search.mark_search_completed!(query: query, raw_results: raw_results)
      Result.new(success?: true, error: nil)
    rescue StandardError => e
      Rails.logger.error("PossibleObservationSlackSearches::RunSearchService error: #{e.message}")
      search.mark_search_failed!(e.message)
      Result.new(success?: false, error: search.search_error)
    end

    private

    attr_reader :search, :creator, :subject

    def build_query
      after_date = search.window_days.days.ago.to_date.iso8601
      mention =
        if subject.slack_user_id.present?
          "<@#{subject.slack_user_id}>"
        else
          name = subject.person.full_name.presence || subject.person.casual_name
          "\"#{name.to_s.gsub('"', '')}\""
        end
      "#{mention} after:#{after_date}"
    end

    def normalize_messages(matches)
      matches.first(PossibleObservationSlackSearch::MAX_MESSAGES).map do |match|
        channel = match["channel"] || {}
        {
          "iid" => match["iid"],
          "team" => match["team"],
          "channel_id" => channel["id"],
          "channel_name" => channel["name"],
          "user" => match["user"],
          "username" => match["username"],
          "ts" => match["ts"],
          "text" => match["text"].to_s,
          "permalink" => match["permalink"],
          "timestamp" => match["ts"]
        }
      end
    end
  end
end
