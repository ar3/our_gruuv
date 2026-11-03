# frozen_string_literal: true

module Llm
  # Step 3 only: given a frozen cue + observee MAAP context, suggest up to 3 rateables.
  # Does not invent people, cues, or rewrite the quote.
  class TranscriptCueRatingsExtractor
    # Prompt version: <major>.<YYYYMMDD>.<minor> — see docs/RULES/prompt-versioning.md
    # 1.20261103.0 — per-cue rating suggestions (no moment discovery)
    PROMPT_VERSION = "1.20261103.0"
    ALLOWED_RATINGS = ObservationRating::DISPLAY_LABELS.except("na").keys.freeze
    ALLOWED_RATEABLE_TYPES = %w[Assignment Ability Aspiration].freeze
    MAX_RATEABLES = 3

    def self.model_id
      MultiTeammateMomentsExtractor.model_id
    end

    def self.prompt_version
      PROMPT_VERSION
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(
      quote:,
      observee_name:,
      observer_name: nil,
      context_text: nil,
      context_catalog: nil,
      organization_id: nil,
      parent: nil,
      triggered_by_teammate_id: nil,
      model_id: nil
    )
      @quote = quote.to_s
      @observee_name = observee_name.to_s
      @observer_name = observer_name.to_s
      @context_text = context_text.to_s
      @context_catalog = context_catalog || {}
      @organization_id = organization_id
      @parent = parent
      @triggered_by_teammate_id = triggered_by_teammate_id
      @model_id = model_id.presence || self.class.model_id
    end

    def call
      return stub_response unless bedrock_configured?

      llm = Llm::Client.call(
        purpose: "transcript_cue_ratings",
        model_id: @model_id,
        system_instructions: system_instructions,
        user_prompt: user_prompt,
        organization_id: @organization_id,
        parent: @parent,
        triggered_by_teammate_id: @triggered_by_teammate_id,
        prompt_version: PROMPT_VERSION
      )
      parse_response(llm.content.to_s)
    rescue StandardError => e
      Rails.logger.warn("TranscriptCueRatingsExtractor failed: #{e.class}: #{e.message}")
      { "summary" => "", "kind" => "kudos", "rateables" => [], "error" => e.message }
    end

    private

    def bedrock_configured?
      ENV["AWS_ACCESS_KEY_ID"].present? || ENV["AWS_PROFILE"].present? ||
        File.exist?(File.expand_path("~/.aws/credentials"))
    end

    def stub_response
      { "summary" => "", "kind" => "kudos", "rateables" => [], "error" => "bedrock_not_configured" }
    end

    def system_instructions
      <<~SYS
        You rate one frozen observation cue for OurGruuv (OGO).
        The quote, observer, and observee are already decided — do NOT invent people, split the quote, or rewrite it.
        Propose up to #{MAX_RATEABLES} rateable objects from the provided catalog that this cue should rate for the observee.
        Prefer Abilities and Assignments; use Aspiration only when the cue clearly maps to a company value/aspiration.
        Each suggestion needs its own confidence (0.0–1.0), rating, and short reasons.
        Also return:
        - kind: "kudos" or "feedback"
        - summary: one short sentence summarizing the moment (NOT a rewrite of the quote)
        - association_reason: why this moment matters for rating (general)
        - rating_reason: overall why the evidence supports the suggested ratings
        Respond with ONLY JSON:
        {"kind":"kudos","summary":"...","association_reason":"...","rating_reason":"...",
         "rateables":[{"rateable_type":"Ability","rateable_id":123,"rateable_name":"...","suggested_rating":"agree","confidence":0.82,"association_reason":"...","rating_reason":"..."}]}
        Use only ids/names from the catalog. Empty rateables is allowed when nothing fits.
      SYS
    end

    def user_prompt
      <<~USER
        Observer: #{@observer_name.presence || "(unknown)"}
        Observee (subject to rate): #{@observee_name.presence || "(unknown)"}

        Frozen quote (do not rewrite):
        #{@quote}

        Catalog for #{@observee_name}:
        #{@context_text.presence || "(none)"}
      USER
    end

    def parse_response(content)
      json = extract_json(content)
      rateables = Array(json["rateables"]).filter_map { |raw| normalize_rateable(raw) }.first(MAX_RATEABLES)
      {
        "kind" => %w[kudos feedback].include?(json["kind"].to_s) ? json["kind"].to_s : "kudos",
        "summary" => json["summary"].to_s.strip.truncate(500),
        "association_reason" => json["association_reason"].to_s.strip.truncate(500),
        "rating_reason" => json["rating_reason"].to_s.strip.truncate(500),
        "rateables" => rateables
      }
    end

    def normalize_rateable(raw)
      h = raw.is_a?(Hash) ? raw.stringify_keys : {}
      type = h["rateable_type"].to_s
      return nil unless ALLOWED_RATEABLE_TYPES.include?(type)

      id = h["rateable_id"].to_i
      return nil if id <= 0
      return nil unless @context_catalog.dig(type, id).present?

      rating = h["suggested_rating"].to_s
      return nil unless ALLOWED_RATINGS.include?(rating)

      confidence = h["confidence"].to_f
      confidence = 0.0 if confidence.nan?
      confidence = [[confidence, 0.0].max, 1.0].min

      {
        "rateable_type" => type,
        "rateable_id" => id,
        "rateable_name" => (@context_catalog.dig(type, id).presence || h["rateable_name"]).to_s,
        "suggested_rating" => rating,
        "confidence" => confidence,
        "association_reason" => h["association_reason"].to_s.strip.truncate(500),
        "rating_reason" => h["rating_reason"].to_s.strip.truncate(500)
      }
    end

    def extract_json(content)
      text = content.to_s.strip
      return {} if text.blank?

      JSON.parse(text)
    rescue JSON::ParserError
      start_idx = text.index("{")
      end_idx = text.rindex("}")
      return {} if start_idx.nil? || end_idx.nil? || end_idx <= start_idx

      JSON.parse(text[start_idx..end_idx])
    rescue JSON::ParserError
      {}
    end
  end
end
