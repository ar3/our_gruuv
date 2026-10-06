# frozen_string_literal: true

module Observations
  class OgoQualityRunner
    ALLOWED_TYPES = %w[Assignment Ability Aspiration].freeze
    ALLOWED_RATINGS = %w[strongly_agree agree disagree strongly_disagree].freeze

    def self.call(observation:, og_consultation:)
      new(observation: observation, og_consultation: og_consultation).call
    end

    def initialize(observation:, og_consultation:)
      @observation = observation
      @consultation = og_consultation
    end

    def call
      unless bedrock_configured?
        fail_consultation("AWS Bedrock is not configured (missing access key, secret, or region).")
        return false
      end

      catalog = OgoConsultCatalog.call(observation: @observation)
      model_id = ENV.fetch("OGO_QUALITY_BEDROCK_MODEL_ID") { Llm::TranscriptMomentsExtractor.default_model_id }
      purpose = OgConsultations::Kinds.fetch(@consultation.kind).llm_purpose
      llm = Llm::Client.call(
        purpose: purpose,
        model_id: model_id,
        system_instructions: Ogo::Prompts::OGO_QUALITY_AGENT,
        user_prompt: user_prompt(catalog),
        organization_id: @observation.company_id,
        triggered_by_teammate_id: @consultation.triggered_by_teammate_id,
        parent: @consultation,
        prompt_version: Ogo::Prompts::PROMPT_VERSION
      )
      raw = llm.content.to_s
      payload = sanitize_payload(parse_json(raw), catalog)

      result = @consultation.result || @consultation.create_ogo_quality_result!
      result.update!(output_text: raw.strip, payload: payload)
      @consultation.update!(
        status: "completed",
        result: result,
        model_id: model_id,
        prompt_version: Ogo::Prompts::PROMPT_VERSION,
        completed_at: Time.current,
        units_completed: 1,
        error_message: nil
      )
      true
    rescue StandardError => e
      Rails.logger.warn("OgoQualityRunner failed: #{e.class}: #{e.message}")
      fail_consultation(e.message)
      false
    end

    private

    def user_prompt(catalog)
      observer = @observation.observer
      observees = @observation.observed_teammates.includes(:person).map { |tm| tm.person.display_name }
      catalog_json = catalog.map do |entry|
        { type: entry.rateable_type, id: entry.id, name: entry.name }
      end

      <<~TXT
        Observer: #{observer.display_name}
        Observee(s): #{observees.join(', ').presence || '(none)'}
        Primary feeling: #{@observation.primary_feeling.presence || '(none)'}
        Secondary feeling: #{@observation.secondary_feeling.presence || '(none)'}

        STORY:
        ---
        #{@observation.story.to_s.truncate(20_000)}
        ---

        SUBJECT CATALOG (only propose from this list):
        #{JSON.pretty_generate(catalog_json)}

        Prompt version: #{Ogo::Prompts::PROMPT_VERSION}
      TXT
    end

    def parse_json(raw)
      text = raw.to_s.strip
      json_str = text[/\A\s*\{.*\}\s*\z/m] || text[/\{.*\}/m]
      return {} if json_str.blank?

      JSON.parse(json_str)
    rescue JSON::ParserError
      {}
    end

    def sanitize_payload(data, catalog)
      data = data.stringify_keys if data.respond_to?(:stringify_keys)
      data = {} unless data.is_a?(Hash)
      allowed_keys = catalog.index_by { |e| "#{e.rateable_type}:#{e.id}" }

      quality_in = data["quality"].is_a?(Hash) ? data["quality"].stringify_keys : {}
      quality = {
        "observation" => aspect(quality_in["observation"]),
        "emotion" => aspect(quality_in["emotion"]),
        "impact" => aspect(quality_in["impact"]),
        "summary" => scrub_user_facing(quality_in["summary"].to_s.squish).truncate(2_000),
        "improvements" => sanitize_improvements(quality_in["improvements"]),
        "ogo_worthy" => ActiveModel::Type::Boolean.new.cast(quality_in["ogo_worthy"]) == true
      }

      if quality.dig("emotion", "score").to_i > Ogo::Prompts::EMOTION_OGO_WORTHY_ABOVE
        quality["ogo_worthy"] = true
      end
      if quality["summary"].blank?
        quality["summary"] =
          "Name who did what (a camera would see it), the feeling it stirred, and who it helped or hurt. That will make this story even more useful."
      end

      objects = []
      if quality["ogo_worthy"]
        Array(data["proposed_objects"]).each do |raw|
          next unless raw.is_a?(Hash)

          h = raw.stringify_keys
          type = h["rateable_type"].to_s
          next unless ALLOWED_TYPES.include?(type)

          id = h["rateable_id"].to_i
          next if id <= 0
          next unless allowed_keys["#{type}:#{id}"]

          rating = h["rating"].to_s
          next unless ALLOWED_RATINGS.include?(rating)

          key = "#{type}:#{id}"
          next if objects.any? { |o| "#{o['rateable_type']}:#{o['rateable_id']}" == key }

          objects << {
            "rateable_type" => type,
            "rateable_id" => id,
            "rateable_name" => allowed_keys[key].name,
            "rating" => rating,
            "reason" => h["reason"].to_s.squish.truncate(500)
          }
          break if objects.size >= 3
        end
      end

      { "quality" => quality, "proposed_objects" => objects }
    end

    def aspect(raw)
      h = raw.is_a?(Hash) ? raw.stringify_keys : {}
      score = h["score"].to_i
      {
        "score" => score.clamp(0, 100),
        "notes" => scrub_user_facing(h["notes"].to_s.squish).truncate(500)
      }
    end

    def sanitize_improvements(raw)
      Array(raw).filter_map do |item|
        text = scrub_user_facing(item.to_s.squish)
        next if text.blank?

        text.truncate(300)
      end.first(3)
    end

    def scrub_user_facing(text)
      text.to_s
          .gsub(/\bnot\s+(?:an?\s+)?ogo[-\s]?worthy\b/i, "could be stronger")
          .gsub(/\bogo[-\s]?worthy\b/i, "useful")
          .gsub(/\bnot worthy\b/i, "could be stronger")
          .squish
    end

    def fail_consultation(message)
      @consultation.update!(
        status: "failed",
        error_message: message.to_s.truncate(10_000),
        model_id: ENV.fetch("OGO_QUALITY_BEDROCK_MODEL_ID") { Llm::TranscriptMomentsExtractor.default_model_id },
        prompt_version: Ogo::Prompts::PROMPT_VERSION,
        completed_at: Time.current
      )
    end

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end
  end
end
