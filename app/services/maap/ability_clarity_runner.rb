# frozen_string_literal: true

module Maap
  class AbilityClarityRunner
    def self.call(ability:, og_consultation:)
      new(ability: ability, og_consultation: og_consultation).call
    end

    def initialize(ability:, og_consultation:)
      @ability = ability
      @consultation = og_consultation
    end

    def call
      unless bedrock_configured?
        fail_consultation('AWS Bedrock is not configured (missing access key, secret, or region).')
        return false
      end

      payload = AbilityClarityPayloadBuilder.call(ability: @ability)
      user_markdown = PayloadRenderer.new(payload).to_markdown
      footer = <<~MD

        ---
        Prompt version: #{Maap::Prompts::MAAP_PROMPTS_VERSION}
      MD

      model_id = ENV.fetch('MAAP_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id }
      llm = Llm::Client.call(
        purpose: 'ability_clarity',
        model_id: model_id,
        system_instructions: Maap::Prompts::ABILITY_CLARITY_AGENT,
        user_prompt: "#{user_markdown}#{footer}",
        organization_id: @ability.company_id,
        triggered_by_teammate_id: @consultation.triggered_by_teammate_id,
        parent: @consultation,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
      )
      raw = llm.content.to_s
      parsed = ClaritySignalParser.call(raw)

      result = @consultation.result || @consultation.create_ability_clarity_result!
      result.update!(output_text: raw.strip, clarity_rating: parsed.rating)
      @consultation.update!(
        status: 'completed',
        result: result,
        model_id: model_id,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        completed_at: Time.current,
        units_completed: 1,
        error_message: nil
      )
      true
    rescue StandardError => e
      Rails.logger.warn("AbilityClarityRunner failed: #{e.class}: #{e.message}")
      fail_consultation(e.message)
      false
    end

    private

    def fail_consultation(message)
      @consultation.update!(
        status: 'failed',
        error_message: message.to_s.truncate(10_000),
        model_id: ENV.fetch('MAAP_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id },
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        completed_at: Time.current
      )
    end

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end
  end
end
