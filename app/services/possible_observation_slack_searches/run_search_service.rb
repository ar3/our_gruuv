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
      queries = build_queries
      raise "Unable to build Slack search queries for this teammate." if queries.empty?

      all_messages = []
      query_metas = []
      pages_fetched = 0
      slack_total = 0

      queries.each do |entry|
        messages, meta = fetch_all_messages(token: token, query: entry[:query])
        tagged = messages.map { |message| message.merge("search_kind" => entry[:kind]) }
        all_messages.concat(tagged)
        pages_fetched += meta[:pages_fetched].to_i
        slack_total += meta[:slack_total].to_i
        query_metas << entry.merge(
          "slack_total" => meta[:slack_total],
          "pages_fetched" => meta[:pages_fetched],
          "messages_count" => messages.size
        )
        search.heartbeat_search_processing!
      end

      messages = dedupe_messages(all_messages)
      display_query = queries.map { |entry| "#{entry[:kind]}: #{entry[:query]}" }.join(" | ")
      meta = {
        slack_total: slack_total,
        pages_fetched: pages_fetched,
        fetched_at: Time.current.iso8601,
        queries: query_metas
      }

      search.mark_search_completed!(query: display_query, messages: messages, meta: meta)
      # Batches are created inside mark_search_completed! (pre-filter + ≤500 slices).
      Result.new(success?: true, error: nil)
    rescue StandardError => e
      Rails.logger.error("PossibleObservationSlackSearches::RunSearchService error: #{e.message}")
      search.mark_search_failed!(e.message)
      Result.new(success?: false, error: search.search_error)
    end

    private

    attr_reader :search, :creator, :subject

    def build_queries
      after_date = search.window_days.days.ago.to_date.iso8601
      queries = []

      about_term =
        if subject.slack_user_id.present?
          "<@#{subject.slack_user_id}>"
        else
          name = subject.person.full_name.presence || subject.person.casual_name
          "\"#{name.to_s.gsub('"', '')}\""
        end
      queries << { kind: "about", query: "#{about_term} after:#{after_date}" }

      if subject.slack_user_id.present?
        queries << { kind: "from", query: "from:<@#{subject.slack_user_id}> after:#{after_date}" }
      end

      queries
    end

    def dedupe_messages(messages)
      seen = Set.new
      messages.filter_map do |message|
        key =
          if message["channel_id"].present? && message["ts"].present?
            "#{message['channel_id']}|#{message['ts']}"
          else
            "#{message['user']}|#{message['text'].to_s[0, 200]}"
          end
        next if seen.include?(key)

        seen.add(key)
        message
      end
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
        slack_total: slack_total.to_i,
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
