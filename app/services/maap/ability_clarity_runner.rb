# frozen_string_literal: true

module Maap
  class AbilityClarityRunner
    def self.call(ability:, maap_agent_run:)
      new(ability: ability, maap_agent_run: maap_agent_run).call
    end

    def initialize(ability:, maap_agent_run:)
      @ability = ability
      @run = maap_agent_run
    end

    def call
      unless bedrock_configured?
        fail_run('AWS Bedrock is not configured (missing access key, secret, or region).')
        return false
      end

      payload = AbilityClarityPayloadBuilder.call(ability: @ability)
      user_markdown = PayloadRenderer.new(payload).to_markdown
      footer = <<~MD

        ---
        Prompt version: #{Maap::Prompts::MAAP_PROMPTS_VERSION}
      MD

      model_id = ENV.fetch('MAAP_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id }
      chat = RubyLLM.chat(model: model_id, provider: :bedrock, assume_model_exists: true)
      chat.with_instructions(Maap::Prompts::ABILITY_CLARITY_AGENT)
      response = chat.ask("#{user_markdown}#{footer}")
      raw = response.content.to_s

      parsed = ClaritySignalParser.call(raw)
      @run.update!(
        status: 'completed',
        output_text: raw.strip,
        clarity_rating: parsed.rating,
        model_id: model_id,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
        error_message: nil
      )
      true
    rescue StandardError => e
      Rails.logger.warn("AbilityClarityRunner failed: #{e.class}: #{e.message}")
      fail_run(e.message)
      false
    end

    private

    def fail_run(message)
      @run.update!(
        status: 'failed',
        error_message: message.to_s.truncate(10_000),
        clarity_rating: nil,
        output_text: nil,
        model_id: ENV.fetch('MAAP_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id },
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
      )
    end

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end
  end
end
