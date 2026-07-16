# frozen_string_literal: true

module Llm
  # Bedrock extractor for noteworthy Slack moments that warrant an OGO (precision over recall).
  class SlackMomentsExtractor
    HAIKU_45_FOUNDATION_SUFFIX = "anthropic.claude-haiku-4-5-20251001-v1:0"
    RATING_WORDS = {
      "strongly_agree" => "Exceptional",
      "agree" => "Solid",
      "disagree" => "Mis-aligned",
      "strongly_disagree" => "Concerning"
    }.freeze
    ALLOWED_RATINGS = RATING_WORDS.keys.freeze
    ALLOWED_RATEABLE_TYPES = %w[Assignment Ability Aspiration].freeze

    def self.default_model_id
      region = RubyLLM.config.bedrock_region.presence || ENV["AWS_REGION"].presence || "us-east-1"
      prefix =
        if region.to_s.match?(/\Aus-gov-/i)
          "us-gov"
        else
          region.to_s.split("-").first.presence || "us"
        end
      "#{prefix}.#{HAIKU_45_FOUNDATION_SUFFIX}"
    end

    def self.call(chunk_text:, subject_name:, context_text: nil, context_catalog: nil)
      new(
        chunk_text: chunk_text,
        subject_name: subject_name,
        context_text: context_text,
        context_catalog: context_catalog
      ).call
    end

    def initialize(chunk_text:, subject_name:, context_text: nil, context_catalog: nil)
      @chunk_text = chunk_text.to_s
      @subject_name = subject_name.to_s
      @context_text = context_text.to_s
      @context_catalog = context_catalog || {}
    end

    def call
      return stub_response unless bedrock_configured?

      model_id = ENV.fetch("SLACK_SEARCH_BEDROCK_MODEL_ID") {
        ENV.fetch("TRANSCRIPT_BEDROCK_MODEL_ID") { self.class.default_model_id }
      }
      chat = RubyLLM.chat(model: model_id, provider: :bedrock, assume_model_exists: true)
      chat.with_instructions(system_instructions)
      response = chat.ask(user_prompt)
      parse_items(response.content.to_s)
    rescue StandardError => e
      Rails.logger.warn(
        "SlackMomentsExtractor failed: #{e.class}: #{e.message} " \
        "(slack_chunk_chars=#{@chunk_text.bytesize})"
      )
      { "items" => [], "error" => e.message }
    end

    private

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end

    def stub_response
      {
        "items" => [],
        "error" => "AWS Bedrock is not configured (missing access key, secret, or region). Set credentials to enable extraction."
      }
    end

    def system_instructions
      <<~TXT.squish
        You select rare, noteworthy Slack moments that deserve an OurGruuv Observation (OGO):
        reinforce something that strengthens community/aspirations, or correct something that harms them.
        Prefer precision over recall — skip routine chatter, logistics, and weak praise.
        Prefer moments that clearly evidence the SUBJECT CONTEXT objects (aspirations, assignment outcomes,
        abilities, goals). Use the exact object names and ids from that context when suggesting links.
        Subject of interest is often "#{@subject_name}", but speaker/recipient may vary.
        Return ONLY valid JSON:
        {"items":[{"kind":"kudos"|"feedback",
        "summary":"This is a story about when <recipient> caused <outcome> by <action>. And this made me feel <impact>.",
        "short_quote":"short exact quote","full_quote":"verbatim quote from message text",
        "speaker_label":"speaker name if known","recipient_label":"recipient name if known",
        "channel_id":"from message header","ts":"from message header","permalink":"from message header",
        "slack_user_id":"speaker user id from message header",
        "suggested_rateable_type":"Assignment"|"Ability"|"Aspiration"|null,
        "suggested_rateable_id":number|null,
        "suggested_rating":"strongly_agree"|"agree"|"disagree"|"strongly_disagree"|null,
        "suggested_goal_id":number|null}]}.
        Rating bands: strongly_agree=Exceptional, agree=Solid, disagree=Mis-aligned, strongly_disagree=Concerning.
        Rules: full_quote/short_quote must come from message text; never invent channel_id/ts/permalink/slack_user_id;
        only use suggested_* ids that appear in SUBJECT CONTEXT; if unsure, leave suggested_* null;
        only include moments clearly worth logging as OGOs. If none, return {"items":[]}.
      TXT
    end

    def user_prompt
      context_block =
        if @context_text.present?
          <<~CTX
            SUBJECT CONTEXT (prefer moments tied to these; use exact ids/names):
            ---
            #{@context_text.truncate(60_000)}
            ---
          CTX
        else
          ""
        end

      <<~TXT
        #{context_block}
        Slack messages (each block starts with a header line of metadata):
        ---
        #{@chunk_text.truncate(120_000)}
        ---
      TXT
    end

    def parse_items(raw)
      json = extract_json_object(raw)
      data = JSON.parse(json)
      items = Array(data["items"]).filter_map do |h|
        next unless h.is_a?(Hash)

        full_quote = h["full_quote"].to_s.strip
        short_quote = h["short_quote"].to_s.strip
        summary = h["summary"].to_s.strip
        legacy_quote = h["quote"].to_s.strip

        full_quote = legacy_quote if full_quote.blank?
        short_quote = legacy_quote if short_quote.blank?
        if summary.blank?
          summary = default_summary(
            recipient_label: h["recipient_label"].to_s,
            quote: short_quote.presence || full_quote.presence || legacy_quote
          )
        end

        suggestion = sanitize_suggestion(h)
        suggestion_line = suggestion_display_line(suggestion)
        summary = prepend_suggestion_to_summary(summary, suggestion_line) if suggestion_line.present?

        {
          "kind" => (h["kind"].to_s == "feedback" ? "feedback" : "kudos"),
          "summary" => summary.truncate(2500),
          "short_quote" => short_quote.truncate(2500),
          "full_quote" => full_quote.truncate(10_000),
          "quote" => compose_display_quote(
            summary: summary,
            short_quote: short_quote,
            full_quote: full_quote
          ).truncate(20_000),
          "speaker_label" => h["speaker_label"].to_s.strip,
          "recipient_label" => h["recipient_label"].to_s.strip,
          "channel_id" => h["channel_id"].to_s.strip,
          "ts" => h["ts"].to_s.strip,
          "permalink" => h["permalink"].to_s.strip,
          "slack_user_id" => h["slack_user_id"].to_s.strip,
          "suggested_rateable_type" => suggestion[:rateable_type],
          "suggested_rateable_id" => suggestion[:rateable_id],
          "suggested_rating" => suggestion[:rating],
          "suggested_goal_id" => suggestion[:goal_id]
        }
      end
      { "items" => items }
    rescue JSON::ParserError => e
      { "items" => [], "error" => "Invalid JSON from model: #{e.message}" }
    end

    def sanitize_suggestion(h)
      type = h["suggested_rateable_type"].to_s
      type = nil unless ALLOWED_RATEABLE_TYPES.include?(type)
      id = h["suggested_rateable_id"].to_i
      id = nil if id <= 0
      if type.present? && id.present?
        unless @context_catalog.blank? || @context_catalog.dig(type, id).present?
          type = nil
          id = nil
        end
      else
        type = nil
        id = nil
      end

      rating = h["suggested_rating"].to_s
      rating = nil unless ALLOWED_RATINGS.include?(rating)

      goal_id = h["suggested_goal_id"].to_i
      goal_id = nil if goal_id <= 0
      if goal_id.present? && !@context_catalog.blank?
        goal_id = nil unless @context_catalog.dig("Goal", goal_id).present?
      end

      { rateable_type: type, rateable_id: id, rating: rating, goal_id: goal_id }
    end

    def suggestion_display_line(suggestion)
      rating_word = RATING_WORDS[suggestion[:rating]]
      object_label =
        if suggestion[:rateable_type].present? && suggestion[:rateable_id].present?
          name = @context_catalog.dig(suggestion[:rateable_type], suggestion[:rateable_id])
          "#{suggestion[:rateable_type]} #{name.presence || "##{suggestion[:rateable_id]}"}"
        end
      goal_label =
        if suggestion[:goal_id].present?
          gname = @context_catalog.dig("Goal", suggestion[:goal_id])
          "Goal #{gname.presence || "##{suggestion[:goal_id]}"}"
        end

      parts = []
      if rating_word.present? && object_label.present?
        parts << "#{rating_word} example of #{object_label}"
      elsif rating_word.present?
        parts << "#{rating_word} example"
      elsif object_label.present?
        parts << "Related to #{object_label}"
      end
      parts << "linked to #{goal_label}" if goal_label.present?
      parts.join("; ").presence
    end

    def prepend_suggestion_to_summary(summary, suggestion_line)
      return summary if summary.to_s.include?("Suggested:")

      "Suggested: #{suggestion_line}. #{summary}"
    end

    def extract_json_object(raw)
      text = raw.to_s.strip
      if (m = text.match(/\{.*\}/m))
        m[0]
      else
        "{}"
      end
    end

    def compose_display_quote(summary:, short_quote:, full_quote:)
      [
        "Summary: #{summary.presence || '(none)'}",
        "",
        "",
        "====================",
        "",
        "",
        "Short quote: #{short_quote.presence || '(none)'}",
        "",
        "",
        "====================",
        "",
        "",
        "Full quote: #{full_quote.presence || '(none)'}"
      ].join("\n")
    end

    def default_summary(recipient_label:, quote:)
      name = recipient_label.presence || "the recipient"
      quote_text = quote.presence || "what happened"
      "This is a story about when #{name} caused an outcome by actions they took. And this made me feel impacted by \"#{quote_text}\"."
    end
  end
end
