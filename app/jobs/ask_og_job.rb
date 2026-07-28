# frozen_string_literal: true

class AskOgJob < ApplicationJob
  queue_as :default

  def perform(og_consultation_id)
    consultation = OgConsultation.find_by(id: og_consultation_id)
    return if consultation.nil?
    return if consultation.terminal?

    consultation.mark_processing!
    runner = OgConsultations::Kinds.runner_class_for(consultation.kind)
    runner.call(og_consultation: consultation)
  end
end
