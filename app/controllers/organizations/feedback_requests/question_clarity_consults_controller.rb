# frozen_string_literal: true

module Organizations
  module FeedbackRequests
    class QuestionClarityConsultsController < Organizations::OrganizationNamespaceBaseController
      before_action :authenticate_person!
      before_action :set_feedback_request
      after_action :verify_authorized

      def create
        authorize @feedback_request, :consult_question_clarity?
        result = ::FeedbackRequests::StartQuestionClarityConsult.call(
          feedback_request: @feedback_request,
          triggered_by_teammate: current_company_teammate
        )

        if result.ok?
          redirect_to fallback_path(fr_question_clarity: 1), notice: consult_notice(result.consultation)
        else
          redirect_to fallback_path, alert: result.error
        end
      end

      def status
        authorize @feedback_request, :consult_question_clarity?
        run = @feedback_request.latest_question_clarity_consultation
        render json: {
          status: run&.status,
          error_message: run&.error_message,
          completed: run&.status == 'completed',
          failed: run&.status == 'failed',
          in_flight: run&.in_flight?
        }
      end

      private

      def set_feedback_request
        @feedback_request = FeedbackRequest.find_by_param(params[:id])
        raise ActiveRecord::RecordNotFound if @feedback_request.company_id != company.id
      end

      def fallback_path(**extra)
        if params[:return_to] == 'answer'
          answer_organization_feedback_request_path(organization, @feedback_request, extra)
        else
          organization_feedback_request_path(organization, @feedback_request, extra)
        end
      end

      def consult_notice(consultation)
        if consultation&.status == 'completed'
          'OG suggestions are ready.'
        elsif consultation&.in_flight?
          'Consulting OG about these questions…'
        else
          'Consultation started.'
        end
      end
    end
  end
end
