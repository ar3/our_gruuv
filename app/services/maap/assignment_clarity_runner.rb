# frozen_string_literal: true

module Maap
  class AssignmentClarityRunner
    def self.call(assignment:, og_consultation:)
      new(assignment: assignment, og_consultation: og_consultation).call
    end

    def initialize(assignment:, og_consultation:)
      @assignment = assignment
      @consultation = og_consultation
    end

    def call
      unless bedrock_configured?
        fail_consultation('AWS Bedrock is not configured (missing access key, secret, or region).')
        return false
      end

      payload = AssignmentClarityPayloadBuilder.call(assignment: @assignment)
      user_markdown = PayloadRenderer.new(payload).to_markdown
      user_markdown += consult_focus_markdown_append(@consultation.consult_focus)
      footer = <<~MD

        ---
        Prompt version: #{Maap::Prompts::MAAP_PROMPTS_VERSION}
      MD

      model_id = ENV.fetch('MAAP_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id }
      llm = Llm::Client.call(
        purpose: 'assignment_clarity',
        model_id: model_id,
        system_instructions: Maap::Prompts::ASSIGNMENT_CLARITY_AGENT,
        user_prompt: "#{user_markdown}#{footer}",
        organization_id: @assignment.company_id,
        triggered_by_teammate_id: @consultation.triggered_by_teammate_id,
        parent: @consultation,
        prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION
      )
      raw = llm.content.to_s
      parsed = AssignmentClarityOutputParser.call(raw)

      result = @consultation.result || @consultation.create_assignment_clarity_result!
      result.update!(
        output_text: raw.strip,
        clarity_rating: parsed.rating,
        clarity_score: parsed.score,
        clarity_recommendations: parsed.recommendations
      )
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
      Rails.logger.warn("AssignmentClarityRunner failed: #{e.class}: #{e.message}")
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

    def consult_focus_markdown_append(text)
      focus = text.to_s.strip
      return '' if focus.blank?

      <<~MD

        ---

        ## User request (focus for this consultation)

        #{focus}
      MD
    end
  end
end
