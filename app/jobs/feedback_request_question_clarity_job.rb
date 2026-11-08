# frozen_string_literal: true

class FeedbackRequestQuestionClarityJob < ApplicationJob
  queue_as :default

  def perform(feedback_request_id, og_consultation_id)
    feedback_request = FeedbackRequest.find_by(id: feedback_request_id)
    consultation = OgConsultation.find_by(id: og_consultation_id)
    return if feedback_request.nil? || consultation.nil?

    consultation.mark_processing!
    runner = OgConsultations::Kinds.runner_class_for(consultation.kind)
    runner.call(feedback_request: feedback_request, og_consultation: consultation)
  end
end
