# frozen_string_literal: true

module FeedbackRequests
  class QuestionClarityRunner
    def self.call(feedback_request:, og_consultation:)
      new(feedback_request: feedback_request, og_consultation: og_consultation).call
    end

    def initialize(feedback_request:, og_consultation:)
      @feedback_request = feedback_request
      @consultation = og_consultation
    end

    def call
      unless bedrock_configured?
        fail_consultation('AWS Bedrock is not configured (missing access key, secret, or region).')
        return false
      end

      model_id = ENV.fetch('FEEDBACK_REQUEST_QUESTION_CLARITY_BEDROCK_MODEL_ID') do
        ENV.fetch('OGO_QUALITY_BEDROCK_MODEL_ID') { Llm::TranscriptMomentsExtractor.default_model_id }
      end
      purpose = OgConsultations::Kinds.fetch(@consultation.kind).llm_purpose
      llm = Llm::Client.call(
        purpose: purpose,
        model_id: model_id,
        system_instructions: QuestionClarityPrompts::SYSTEM,
        user_prompt: user_prompt,
        organization_id: @feedback_request.company_id,
        triggered_by_teammate_id: @consultation.triggered_by_teammate_id,
        parent: @consultation,
        prompt_version: QuestionClarityPrompts::PROMPT_VERSION
      )
      raw = llm.content.to_s
      payload = sanitize_payload(parse_json(raw))

      result = @consultation.result || @consultation.create_feedback_request_question_clarity_result!
      result.update!(output_text: raw.strip, payload: payload)
      @consultation.update!(
        status: 'completed',
        result: result,
        model_id: model_id,
        prompt_version: QuestionClarityPrompts::PROMPT_VERSION,
        completed_at: Time.current,
        units_completed: 1,
        error_message: nil
      )
      true
    rescue StandardError => e
      Rails.logger.warn("FeedbackRequests::QuestionClarityRunner failed: #{e.class}: #{e.message}")
      fail_consultation(e.message)
      false
    end

    private

    def user_prompt
      subject_name = @feedback_request.subject_of_feedback_teammate&.person&.display_name || 'the subject'
      questions = @feedback_request.feedback_request_questions.includes(:rateable).order(:position).map do |q|
        rateable = q.rateable
        {
          feedback_request_question_id: q.id,
          question_text: q.question_text,
          rateable_type: q.rateable_type,
          rateable_name: rateable_name(rateable),
          object_context: object_context(rateable)
        }
      end

      <<~TXT
        Feedback request subject: #{subject_name}
        Subject line: #{@feedback_request.subject_line}
        System-generated: #{@feedback_request.system_generated?}

        QUESTIONS:
        #{JSON.pretty_generate(questions)}

        Prompt version: #{QuestionClarityPrompts::PROMPT_VERSION}
      TXT
    end

    def rateable_name(rateable)
      return nil unless rateable

      rateable.try(:name).presence || rateable.try(:title).presence
    end

    def object_context(rateable)
      case rateable
      when Aspiration
        { description: rateable.description.to_s.truncate(1_500) }
      when Assignment
        {
          tagline: rateable.tagline.to_s.truncate(500),
          required_activities: rateable.required_activities.to_s.truncate(1_500),
          sentiment_outcomes: rateable.assignment_outcomes.where(outcome_type: 'sentiment').order(:created_at).pluck(:description).first(8)
        }
      when Ability
        {
          description: rateable.try(:description).to_s.truncate(1_500),
          milestones: (1..5).filter_map do |level|
            text = rateable.milestone_description(level).to_s.truncate(400)
            next if text.blank?

            { level: level, description: text }
          end
        }
      else
        {}
      end
    end

    def parse_json(raw)
      text = raw.to_s.strip
      json_str = text[/\A\s*\{.*\}\s*\z/m] || text[/\{.*\}/m]
      return {} if json_str.blank?

      JSON.parse(json_str)
    rescue JSON::ParserError
      {}
    end

    def sanitize_payload(data)
      data = data.stringify_keys if data.respond_to?(:stringify_keys)
      data = {} unless data.is_a?(Hash)
      allowed_ids = @feedback_request.feedback_request_questions.pluck(:id).to_set

      suggestions = Array(data['suggestions']).filter_map do |row|
        next unless row.is_a?(Hash)

        row = row.stringify_keys
        qid = row['feedback_request_question_id'].to_i
        next unless allowed_ids.include?(qid)

        text = row['suggested_question_text'].to_s.squish.truncate(4_000)
        next if text.blank?

        {
          'feedback_request_question_id' => qid,
          'suggested_question_text' => text,
          'rationale' => row['rationale'].to_s.squish.truncate(1_000)
        }
      end

      {
        'summary' => data['summary'].to_s.squish.truncate(1_000),
        'suggestions' => suggestions
      }
    end

    def bedrock_configured?
      ENV['AWS_ACCESS_KEY_ID'].present? && ENV['AWS_SECRET_ACCESS_KEY'].present? && ENV['AWS_REGION'].present?
    end

    def fail_consultation(message)
      @consultation.update!(
        status: 'failed',
        completed_at: Time.current,
        error_message: message.to_s.truncate(1_000)
      )
    end
  end
end
