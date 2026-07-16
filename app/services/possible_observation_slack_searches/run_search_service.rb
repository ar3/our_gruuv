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
      messages, meta = fetch_all_messages(token: token, query: query)

      search.mark_search_completed!(query: query, messages: messages, meta: meta)
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

    def fetch_all_messages(token:, query:)
      all_messages = []
      page = 1
      slack_total = nil
      pages_fetched = 0

      loop do
        data = request_page(token: token, query: query, page: page)
        unless data["ok"]
          raise "Slack search failed: #{data['error'] || 'unknown error'}"
        end

        matches = data.dig("messages", "matches") || []
        all_messages.concat(normalize_messages(matches))
        pages_fetched += 1
        slack_total = data.dig("messages", "total") if slack_total.nil?
        search.heartbeat_search_processing!

        paging = data.dig("messages", "paging") || {}
        total_pages = paging["pages"].to_i
        break if matches.empty?
        break if total_pages.positive? && page >= total_pages
        break if page >= PossibleObservationSlackSearch::MAX_PAGES

        page += 1
      end

      meta = {
        slack_total: slack_total,
        pages_fetched: pages_fetched,
        fetched_at: Time.current.iso8601
      }
      [all_messages, meta]
    end

    def request_page(token:, query:, page:)
      response = HTTP.auth("Bearer #{token}")
                     .get(
                       "https://slack.com/api/search.messages",
                       params: {
                         query: query,
                         count: PossibleObservationSlackSearch::PAGE_SIZE,
                         page: page,
                         sort: "timestamp",
                         sort_dir: "desc",
                         highlight: false
                       }
                     )
      JSON.parse(response.body.to_s)
    end

    def normalize_messages(matches)
      matches.map do |match|
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
