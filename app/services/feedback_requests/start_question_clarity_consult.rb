# frozen_string_literal: true

module FeedbackRequests
  class StartQuestionClarityConsult
    Result = Data.define(:ok, :feedback_request, :consultation, :error) do
      def ok?
        ok
      end
    end

    def self.call(**kwargs)
      new(**kwargs).call
    end

    def initialize(feedback_request:, triggered_by_teammate:)
      @feedback_request = feedback_request
      @triggered_by_teammate = triggered_by_teammate
    end

    def call
      return fail_result('Add questions before consulting OG.') if @feedback_request.feedback_request_questions.empty?

      existing = @feedback_request.latest_question_clarity_consultation
      if existing&.in_flight?
        return Result.new(ok: true, feedback_request: @feedback_request, consultation: existing, error: nil)
      end
      if existing&.status == 'completed'
        return Result.new(ok: true, feedback_request: @feedback_request, consultation: existing, error: nil)
      end

      entry = OgConsultations::Kinds.fetch(OgConsultation::KIND_FEEDBACK_REQUEST_QUESTION_CLARITY)
      consultation = OgConsultation.create!(
        kind: entry.kind,
        subject: @feedback_request,
        organization_id: @feedback_request.company_id,
        triggered_by_teammate: @triggered_by_teammate,
        status: 'pending',
        billable: entry.billable,
        prompt_version: QuestionClarityPrompts::PROMPT_VERSION,
        units_total: 1,
        units_completed: 0
      )
      result = FeedbackRequestQuestionClarityResult.create!(og_consultation: consultation, payload: {})
      consultation.update!(result: result)
      FeedbackRequestQuestionClarityJob.perform_later(@feedback_request.id, consultation.id)

      Result.new(ok: true, feedback_request: @feedback_request, consultation: consultation, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      fail_result(e.record.errors.full_messages.to_sentence.presence || e.message)
    end

    private

    def fail_result(message)
      Result.new(ok: false, feedback_request: @feedback_request, consultation: nil, error: message)
    end
  end
end
