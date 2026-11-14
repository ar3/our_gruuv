# frozen_string_literal: true

module Assistant
  # Multi-turn MAAP Suggestion chat (kind still seat_suggestion for billing continuity).
  # Routes by suggestion_focus: unset → ask/infer; seat / assignment / abilities → focused prompts.
  class SeatSuggestionRunner
    def self.call(og_consultation:)
      new(og_consultation: og_consultation).call
    end

    def initialize(og_consultation:)
      @consultation = og_consultation
      @result = og_consultation.result
    end

    def call
      unless @result.is_a?(AskOgResult)
        fail_consultation("MAAP Suggestion result missing")
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
      conversation_text = @result.messages_for_prompt
        .select(&:user?)
        .map(&:body)
        .compact_blank
        .join("\n")

      context = ContextBuilder.call(
        organization: @consultation.organization,
        company_teammate: teammate
      )

      prior_focus = MaapSuggestionFocus.from_tool_context(@result.tool_context)
      tool_context = gather_context(
        focus: prior_focus,
        context: context,
        query: prompt_query,
        conversation_text: conversation_text
      )
      tool_context = tool_context.stringify_keys
      tool_context["suggestion_focus"] = prior_focus if prior_focus
      @result.update!(tool_context: tool_context)

      focus = prior_focus
      system_instructions, prompt_version, allowed_tools = prompt_pack_for(focus)

      model_id = ENV.fetch("SEAT_SUGGESTION_BEDROCK_MODEL_ID") { Llm::SlackMomentsExtractor.model_id }
      purpose = OgConsultations::Kinds.fetch(@consultation.kind).llm_purpose
      user_prompt = build_user_prompt(tool_context, allowed_tools: allowed_tools, prompt_version: prompt_version)

      llm = Llm::Client.call(
        purpose: purpose,
        model_id: model_id,
        system_instructions: system_instructions,
        user_prompt: user_prompt,
        organization_id: @consultation.organization_id,
        triggered_by_teammate_id: @consultation.triggered_by_teammate_id,
        parent: @consultation,
        prompt_version: prompt_version
      )

      parsed = ParseAskOgResponse.call(llm.content.to_s)
      next_focus = MaapSuggestionFocus.normalize(parsed[:focus]) || focus
      if next_focus != focus
        tool_context = tool_context.merge("suggestion_focus" => next_focus)
        @result.update!(tool_context: tool_context)
        focus = next_focus
      end

      allowed_tools = focus.present? ? MaapSuggestionFocus.tools_for(focus) : []
      actions = Array(parsed[:proposed_actions]).select { |a| allowed_tools.include?(a["tool"]) }

      @result.append_message!(
        role: AskOgMessage::ROLE_ASSISTANT,
        body: parsed[:answer],
        proposed_actions: actions
      )
      @result.update!(
        answer_text: parsed[:answer],
        proposed_actions: actions
      )
      @consultation.update!(
        status: "completed",
        result: @result,
        model_id: model_id,
        prompt_version: prompt_version,
        completed_at: Time.current,
        units_completed: @consultation.units_total,
        error_message: nil
      )
      true
    rescue StandardError => e
      Rails.logger.warn("SeatSuggestionRunner failed: #{e.class}: #{e.message}")
      fail_consultation(e.message)
      false
    end

    private

    def prompt_pack_for(focus)
      case focus
      when MaapSuggestionFocus::ASSIGNMENT
        [
          AssignmentSuggestionPrompts::SYSTEM,
          AssignmentSuggestionPrompts::ASSIGNMENT_SUGGESTION_PROMPT_VERSION,
          MaapSuggestionFocus.tools_for(focus)
        ]
      when MaapSuggestionFocus::ABILITIES
        [
          AbilitySuggestionPrompts::SYSTEM,
          AbilitySuggestionPrompts::ABILITY_SUGGESTION_PROMPT_VERSION,
          MaapSuggestionFocus.tools_for(focus)
        ]
      when MaapSuggestionFocus::SEAT
        [
          SeatSuggestionPrompts::SYSTEM,
          SeatSuggestionPrompts::SEAT_SUGGESTION_PROMPT_VERSION,
          MaapSuggestionFocus.tools_for(focus)
        ]
      else
        [
          MaapSuggestionFocusPrompts::SYSTEM,
          MaapSuggestionFocusPrompts::FOCUS_PROMPT_VERSION,
          []
        ]
      end
    end

    def gather_context(focus:, context:, query:, conversation_text:)
      case focus
      when MaapSuggestionFocus::ASSIGNMENT
        GatherAssignmentSuggestionContext.call(
          context: context,
          query: query,
          conversation_text: conversation_text
        )
      when MaapSuggestionFocus::ABILITIES
        GatherAbilitySuggestionContext.call(
          context: context,
          query: query,
          conversation_text: conversation_text
        )
      else
        # Unset focus and Seat share the rich MAAP pack (helps infer Seat vs Assignment).
        GatherSeatSuggestionContext.call(
          context: context,
          query: query,
          conversation_text: conversation_text
        )
      end
    end

    def build_user_prompt(tool_context, allowed_tools:, prompt_version:)
      turns = @result.messages_for_prompt.map do |message|
        {
          role: message.role,
          content: message.body,
          proposed_actions: message.assistant? ? message.proposed_actions : nil
        }.compact
      end

      schemas = AgentTools::Registry.write_tool_schemas.slice(*allowed_tools)

      <<~PROMPT
        Conversation (most recent #{AskOgResult::TURN_WINDOW} turns, oldest first):
        #{JSON.pretty_generate(turns)}

        Org MAAP context for the latest user message (JSON):
        #{JSON.pretty_generate(tool_context)}

        Write tool schemas (JSON):
        #{JSON.pretty_generate(schemas)}

        ---
        Prompt version: #{prompt_version}
      PROMPT
    end

    def fail_consultation(message)
      @consultation.update!(
        status: "failed",
        error_message: message.to_s.truncate(10_000),
        model_id: ENV.fetch("SEAT_SUGGESTION_BEDROCK_MODEL_ID") { Llm::SlackMomentsExtractor.model_id },
        prompt_version: SeatSuggestionPrompts::SEAT_SUGGESTION_PROMPT_VERSION,
        completed_at: Time.current
      )
    end

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end
  end
end
