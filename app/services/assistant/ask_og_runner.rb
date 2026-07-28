# frozen_string_literal: true

module Assistant
  # Multi-turn Ask OG: gather read-tool context, call LLM with a 5-message window,
  # append an assistant message + proposed write actions. Never executes write tools.
  class AskOgRunner
    def self.call(og_consultation:)
      new(og_consultation: og_consultation).call
    end

    def initialize(og_consultation:)
      @consultation = og_consultation
      @result = og_consultation.result
    end

    def call
      unless @result.is_a?(AskOgResult)
        fail_consultation("Ask OG result missing")
        return false
      end

      unless bedrock_configured?
        fail_consultation("AWS Bedrock is not configured (missing access key, secret, or region).")
        return false
      end

      teammate = @consultation.triggered_by_teammate
      if teammate.nil?
        fail_consultation("Missing triggered_by_teammate")
        return false
      end

      latest_user = @result.ask_og_messages.user_messages.ordered.last
      prompt_query = latest_user&.body.presence || @result.query

      context = ContextBuilder.call(
        organization: @consultation.organization,
        company_teammate: teammate
      )
      tool_context = GatherToolContext.call(context: context, query: prompt_query)
      @result.update!(tool_context: tool_context)

      model_id = ENV.fetch("ASK_OG_BEDROCK_MODEL_ID") { Llm::TranscriptMomentsExtractor.default_model_id }
      purpose = OgConsultations::Kinds.fetch(@consultation.kind).llm_purpose
      user_prompt = build_user_prompt(tool_context)

      llm = Llm::Client.call(
        purpose: purpose,
        model_id: model_id,
        system_instructions: Assistant::Prompts::SYSTEM,
        user_prompt: user_prompt,
        organization_id: @consultation.organization_id,
        triggered_by_teammate_id: @consultation.triggered_by_teammate_id,
        parent: @consultation,
        prompt_version: Assistant::Prompts::ASK_OG_PROMPT_VERSION
      )

      parsed = ParseAskOgResponse.call(llm.content.to_s)
      @result.append_message!(
        role: AskOgMessage::ROLE_ASSISTANT,
        body: parsed[:answer],
        proposed_actions: parsed[:proposed_actions]
      )
      @result.update!(
        answer_text: parsed[:answer],
        proposed_actions: parsed[:proposed_actions]
      )
      @consultation.update!(
        status: "completed",
        result: @result,
        model_id: model_id,
        prompt_version: Assistant::Prompts::ASK_OG_PROMPT_VERSION,
        completed_at: Time.current,
        units_completed: @consultation.units_total,
        error_message: nil
      )
      true
    rescue StandardError => e
      Rails.logger.warn("AskOgRunner failed: #{e.class}: #{e.message}")
      fail_consultation(e.message)
      false
    end

    private

    def build_user_prompt(tool_context)
      turns = @result.messages_for_prompt.map do |message|
        {
          role: message.role,
          content: message.body,
          proposed_actions: message.assistant? ? message.proposed_actions : nil
        }.compact
      end

      <<~PROMPT
        Conversation (most recent #{AskOgResult::TURN_WINDOW} turns, oldest first):
        #{JSON.pretty_generate(turns)}

        Tool context for the latest user message (JSON):
        #{JSON.pretty_generate(tool_context)}

        Write tool schemas (JSON):
        #{JSON.pretty_generate(AgentTools::Registry.write_tool_schemas)}

        ---
        Prompt version: #{Assistant::Prompts::ASK_OG_PROMPT_VERSION}
      PROMPT
    end

    def fail_consultation(message)
      @consultation.update!(
        status: "failed",
        error_message: message.to_s.truncate(10_000),
        model_id: ENV.fetch("ASK_OG_BEDROCK_MODEL_ID") { Llm::TranscriptMomentsExtractor.default_model_id },
        prompt_version: Assistant::Prompts::ASK_OG_PROMPT_VERSION,
        completed_at: Time.current
      )
    end

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end
  end
end
