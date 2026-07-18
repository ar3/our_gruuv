# frozen_string_literal: true

module Llm
  # Bedrock extractor for noteworthy Slack moments that warrant an OGO (precision over recall).
  # Default: Claude Sonnet 4.5 via Bedrock regional inference profile (override with SLACK_SEARCH_BEDROCK_MODEL_ID).
  class SlackMomentsExtractor
    SONNET_45_FOUNDATION_SUFFIX = "anthropic.claude-sonnet-4-5-20250929-v1:0"
    RATING_WORDS = {
      "strongly_agree" => "Exceptional",
      "agree" => "Solid",
      "disagree" => "Mis-aligned",
      "strongly_disagree" => "Concerning"
    }.freeze
    ALLOWED_RATINGS = RATING_WORDS.keys.freeze
    ALLOWED_RATEABLE_TYPES = %w[Assignment Ability Aspiration].freeze
    # Model may return weaker hits; drop these before review.
    MIN_RETURN_CONFIDENCE = 0.5
    # Auto-check Include when speaker/subject resolve and confidence is high.
    INCLUDE_CONFIDENCE_THRESHOLD = 0.75

    def self.default_model_id
      region = RubyLLM.config.bedrock_region.presence || ENV["AWS_REGION"].presence || "us-east-1"
      prefix =
        if region.to_s.match?(/\Aus-gov-/i)
          "us-gov"
        else
          region.to_s.split("-").first.presence || "us"
        end
      "#{prefix}.#{SONNET_45_FOUNDATION_SUFFIX}"
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

      model_id = ENV.fetch("SLACK_SEARCH_BEDROCK_MODEL_ID") { self.class.default_model_id }
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
        Prefer precision over recall — skip routine chatter, logistics, status updates, and empty/generic
        praise with no named person or concrete work.
        Default OGO-worthy evidence is a completed action with clear impact or outcome.
        Offers, availability, and routine clarification are usually not Exceptional; often omit them or rate them
        no higher than Solid with lower confidence.
        Exception: a sharp, leading question that clearly shapes decisions or value can be Solid — not Exceptional —
        when the value is obvious.
        Confidence calibration:
        - Peer praise of "#{@subject_name}" (thanks / great work / recognition directed at them) is a strong signal.
          When the praised work is identifiable, confidence is usually >= 0.80. That does not automatically mean
          Exceptional rating — use Solid unless the evidence clearly exceeds expectations.
        - Status-only confirmations ("done!", "shipped", "finished", or a bare link) without a clear description of
          what was completed and what changed are weak evidence: omit, or keep confidence <= 0.65.
        - Shares, cross-posts, and forwards have low confidence unless the message itself makes the result or value
          clear. If readers cannot see the outcome from the message text alone, omit or keep confidence <= 0.65.
        Prefer moments that clearly evidence the SUBJECT CONTEXT objects (aspirations, assignment outcomes,
        abilities, goals). Use the exact object names and ids from that context when suggesting links.
        Speaker identity: the message poster is the speaker (from the message header username/user).
        When the speaker says "I", "me", "my", or describes their own work in first person, that action belongs
        to the speaker — never to people who are only @mentioned, informed, helped, asked, or discussed.
        The OGO subject (recipient_label) must be the person whose action caused the outcome — usually the
        speaker for first-person posts. Never invent that "#{@subject_name}" did the work if the speaker's
        first-person statement or the evidence shows another person did it.
        Only return candidates where "#{@subject_name}" is that actor/subject. If "#{@subject_name}" is only
        the audience, addressee, or mention in someone else's update, omit the candidate.
        Set speaker_label to the poster, recipient_label to the actual actor/subject (must be "#{@subject_name}"),
        and target_is_subject=true only when that conclusion is clear. Write the summary about
        "#{@subject_name}" only when they are truly the actor. Omit if actor/subject identity is ambiguous.
        For each candidate, score confidence from 0.0 to 1.0:
        0.90–1.00 = unmistakable OGO (specific action/outcome/impact; clear speaker and subject; often peer praise
        plus concrete work; strong MAAP/goal link);
        0.80–0.89 = strong OGO — clear peer praise of "#{@subject_name}" for identifiable work, or clear
        action/outcome with only minor ambiguity;
        0.75–0.79 = solid OGO with some ambiguity but still worth reviewing;
        0.50–0.74 = borderline or thin evidence — return for review with lower confidence;
        below 0.50 = omit entirely (do not list).
        Return ONLY valid JSON:
        {"items":[{"kind":"kudos"|"feedback",
        "confidence":0.0-1.0,
        "target_is_subject":true,
        "summary":"This is a story about when <recipient> caused <outcome> by <action>. And this made me feel <impact>.",
        "short_quote":"short exact quote","full_quote":"verbatim quote from message text",
        "speaker_label":"speaker name if known","recipient_label":"recipient name if known",
        "channel_id":"from message header","ts":"from message header","permalink":"from message header",
        "slack_user_id":"speaker user id from message header",
        "suggested_rateable_type":"Assignment"|"Ability"|"Aspiration"|null,
        "suggested_rateable_id":number|null,
        "suggested_rating":"strongly_agree"|"agree"|"disagree"|"strongly_disagree"|null,
        "association_reason":"one concise sentence explaining why the evidence maps to this object",
        "rating_reason":"one concise sentence explaining why the evidence warrants this rating",
        "suggested_goal_id":number|null}]}.
        Rating bands: strongly_agree=Exceptional, agree=Solid, disagree=Mis-aligned, strongly_disagree=Concerning.
        Kind follows rating: Exceptional/Solid => kudos; Mis-aligned/Concerning => feedback.
        Rules: full_quote/short_quote must come from message text; never invent channel_id/ts/permalink/slack_user_id;
        every returned item must have a rateable object, rating, association_reason, and rating_reason;
        only use suggested_* ids that appear in SUBJECT CONTEXT; if unsure, omit the item;
        only include moments clearly worth logging as OGOs with confidence >= #{MIN_RETURN_CONFIDENCE};
        when unsure between including and omitting, omit. If none, return {"items":[]}.
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
        next unless ActiveModel::Type::Boolean.new.cast(h["target_is_subject"])
        next unless target_recipient_label?(h["recipient_label"])

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
        next unless complete_suggestion?(suggestion, h)

        confidence = sanitize_confidence(h["confidence"])
        next if confidence < MIN_RETURN_CONFIDENCE
        association_reason = sanitize_reason(h["association_reason"])
        rating_reason = sanitize_reason(h["rating_reason"])
        rateable_name = @context_catalog.dig(suggestion[:rateable_type], suggestion[:rateable_id]).to_s
        rating_label = RATING_WORDS[suggestion[:rating]]
        rateable_type_label = suggestion[:rateable_type] == "Aspiration" ? "Value" : suggestion[:rateable_type]

        {
          "kind" => kind_for_rating(suggestion[:rating]),
          "confidence" => confidence,
          "target_is_subject" => true,
          "summary" => summary.truncate(2500),
          "short_quote" => short_quote.truncate(2500),
          "full_quote" => full_quote.truncate(10_000),
          "quote" => compose_display_quote(
            summary: summary,
            short_quote: short_quote,
            full_quote: full_quote,
            rating_label: rating_label,
            rateable_type_label: rateable_type_label,
            rateable_name: rateable_name,
            association_reason: association_reason,
            rating_reason: rating_reason
          ).truncate(20_000),
          "speaker_label" => h["speaker_label"].to_s.strip,
          "recipient_label" => h["recipient_label"].to_s.strip,
          "channel_id" => h["channel_id"].to_s.strip,
          "ts" => h["ts"].to_s.strip,
          "permalink" => h["permalink"].to_s.strip,
          "slack_user_id" => h["slack_user_id"].to_s.strip,
          "suggested_rateable_type" => suggestion[:rateable_type],
          "suggested_rateable_id" => suggestion[:rateable_id],
          "suggested_rateable_name" => rateable_name,
          "suggested_rating" => suggestion[:rating],
          "association_reason" => association_reason,
          "rating_reason" => rating_reason,
          "suggested_goal_id" => suggestion[:goal_id]
        }
      end
      { "items" => items.sort_by { |item| [-item["confidence"].to_f, item["ts"].to_s] } }
    rescue JSON::ParserError => e
      { "items" => [], "error" => "Invalid JSON from model: #{e.message}" }
    end

    def kind_for_rating(rating)
      case rating.to_s
      when "disagree", "strongly_disagree"
        "feedback"
      else
        "kudos"
      end
    end

    def sanitize_confidence(value)
      conf = Float(value)
      conf = 0.0 if conf.nan?
      conf.clamp(0.0, 1.0).round(2)
    rescue ArgumentError, TypeError
      0.0
    end

    def target_recipient_label?(label)
      normalized_label = normalize_name(label)
      return false if normalized_label.blank?

      target_names.any? do |name|
        normalized_name = normalize_name(name)
        normalized_name.present? && normalized_label.match?(/(?:\A|\s)#{Regexp.escape(normalized_name)}(?:\s|\z)/)
      end
    end

    def target_names
      @target_names ||= [@subject_name, @subject_name.split.first].compact_blank.uniq
    end

    def normalize_name(value)
      value.to_s.downcase.gsub(/[^a-z0-9]+/, " ").squish
    end

    def complete_suggestion?(suggestion, raw)
      suggestion[:rateable_type].present? &&
        suggestion[:rateable_id].present? &&
        suggestion[:rating].present? &&
        raw["association_reason"].present? &&
        raw["rating_reason"].present?
    end

    def sanitize_reason(value)
      value.to_s.squish.sub(/\A(?:because\s+)/i, "").sub(/[.?!]+\z/, "").truncate(500)
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

    def extract_json_object(raw)
      text = raw.to_s.strip
      if (m = text.match(/\{.*\}/m))
        m[0]
      else
        "{}"
      end
    end

    def compose_display_quote(
      summary:, short_quote:, full_quote:, rating_label:, rateable_type_label:, rateable_name:,
      association_reason:, rating_reason:
    )
      [
        "OG is suggesting: #{rating_label} example of the #{rateable_type_label}, #{rateable_name}.",
        "OG thought it was an example of #{rateable_name} because #{association_reason}.",
        "OG thought it was a #{rating_label} example because #{rating_reason}.",
        "",
        "",
        "====================",
        "",
        "",
        summary.presence || "(none)",
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
