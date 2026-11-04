# frozen_string_literal: true

module CheckIns
  class PeriodBriefRunner
    RATING_LEAK_PATTERN = /
      \b(
        you\s+should\s+(?:rate|mark|choose|pick)|
        (?:i|we)\s+recommend\s+(?:you\s+)?(?:rate|mark|choose)|
        recommend(?:ed|ing)?\s+(?:a\s+)?(?:rating|that\s+you\s+rate)|
        mark\s+them\s+as\s+(?:working\s+to\s+meet|meeting|exceeding|developing|accomplished|exceptional)|
        (?:rate|rating)\s+them\s+(?:as\s+)?(?:working\s+to\s+meet|meeting|exceeding|developing|accomplished|exceptional)
      )\b
    /ix

    def self.call(check_in:, og_consultation:, viewer_person:)
      new(check_in: check_in, og_consultation: og_consultation, viewer_person: viewer_person).call
    end

    def initialize(check_in:, og_consultation:, viewer_person:)
      @check_in = check_in
      @consultation = og_consultation
      @viewer_person = viewer_person
    end

    def call
      unless bedrock_configured?
        fail_consultation("AWS Bedrock is not configured (missing access key, secret, or region).")
        return false
      end

      kind = check_in_kind
      teammate = @check_in.company_teammate
      context = PeriodBriefContextBuilder.call(
        organization: @consultation.organization,
        viewer_person: @viewer_person,
        teammate: teammate,
        check_in: @check_in,
        check_in_kind: kind
      )

      model_id = ENV.fetch("CHECK_IN_PERIOD_BRIEF_BEDROCK_MODEL_ID") { Llm::TranscriptMomentsExtractor.default_model_id }
      purpose = OgConsultations::Kinds.fetch(@consultation.kind).llm_purpose
      llm = Llm::Client.call(
        purpose: purpose,
        model_id: model_id,
        system_instructions: PeriodBriefPrompts::SYSTEM_INSTRUCTIONS,
        user_prompt: context.user_prompt,
        organization_id: @consultation.organization_id,
        triggered_by_teammate_id: @consultation.triggered_by_teammate_id,
        parent: @consultation,
        prompt_version: PeriodBriefPrompts::PROMPT_VERSION
      )

      summary_body = scrub_summary(llm.content.to_s)
      if summary_body.blank?
        summary_body = "Little is on record for this period in the context OG can see."
      end

      # Prior-check-in / algorithm context sits above the "OG's brief of…" header.
      assembled_parts = []
      if context.position_algorithm_paragraph.present?
        assembled_parts << context.position_algorithm_paragraph
        assembled_parts << ""
      end
      assembled_parts.concat(
        [
          context.preface,
          context.visibility_note,
          "",
          summary_body,
          "",
          PeriodBriefPrompts::CLOSING_LINE
        ]
      )
      assembled = assembled_parts.join("\n")

      result = @consultation.result || @consultation.create_check_in_period_brief_result!
      result.update!(
        output_text: assembled.strip,
        payload: {
          "summary_body" => summary_body,
          "period_start_on" => context.period_start_on.to_s,
          "period_end_on" => context.period_end_on.to_s,
          "object_label" => context.object_label,
          "casual_name" => context.casual_name,
          "viewer_casual_name" => context.viewer_casual_name,
          "visibility_note" => context.visibility_note,
          "position_algorithm_paragraph" => context.position_algorithm_paragraph,
          "check_in_kind" => kind
        }
      )
      @consultation.update!(
        status: "completed",
        result: result,
        model_id: model_id,
        prompt_version: PeriodBriefPrompts::PROMPT_VERSION,
        completed_at: Time.current,
        units_completed: 1,
        error_message: nil
      )
      true
    rescue StandardError => e
      Rails.logger.warn("PeriodBriefRunner failed: #{e.class}: #{e.message}")
      fail_consultation(e.message)
      false
    end

    private

    def check_in_kind
      case @check_in
      when AssignmentCheckIn then "assignment"
      when AspirationCheckIn then "aspiration"
      when PositionCheckIn then "position"
      else
        raise ArgumentError, "Unsupported check-in #{@check_in.class.name}"
      end
    end

    def scrub_summary(raw)
      text = raw.to_s.strip
      text = text.gsub(RATING_LEAK_PATTERN, "[rating guidance removed]")
      text.truncate(8_000)
    end

    def fail_consultation(message)
      @consultation.update!(
        status: "failed",
        error_message: message.to_s.truncate(10_000),
        model_id: ENV.fetch("CHECK_IN_PERIOD_BRIEF_BEDROCK_MODEL_ID") { Llm::TranscriptMomentsExtractor.default_model_id },
        prompt_version: PeriodBriefPrompts::PROMPT_VERSION,
        completed_at: Time.current
      )
    end

    def bedrock_configured?
      cfg = RubyLLM.config
      cfg.bedrock_api_key.present? && cfg.bedrock_secret_key.present? && cfg.bedrock_region.present?
    end
  end
end
