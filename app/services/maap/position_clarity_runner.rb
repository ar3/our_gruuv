# frozen_string_literal: true

module Maap
  class PositionClarityRunner
    def self.call(position:, maap_agent_run:)
      new(position: position, maap_agent_run: maap_agent_run).call
    end

    def initialize(position:, maap_agent_run:)
      @position = position
      @run = maap_agent_run
    end

    def call
      unless bedrock_configured?
        fail_run('AWS Bedrock is not configured (missing access key, secret, or region).')
        return false
      end

      payload = PositionClarityPayloadBuilder.call(position: @position)
      user_markdown = PayloadRenderer.new(payload).to_markdown
      footer = <<~MD

        ---
        Prompt version: #{Maap::Prompts::MAAP_PROMPTS_VERSION}
      MD

      model_id = ENV.fetch('MAAP_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id }
      chat = RubyLLM.chat(model: model_id, provider: :bedrock, assume_model_exists: true)
      chat.with_instructions(Maap::Prompts::POSITION_CLARITY_AGENT)
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
      Rails.logger.warn("PositionClarityRunner failed: #{e.class}: #{e.message}")
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
