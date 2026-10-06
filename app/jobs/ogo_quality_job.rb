# frozen_string_literal: true

class OgoQualityJob < ApplicationJob
  queue_as :default

  def perform(observation_id, og_consultation_id)
    observation = Observation.find_by(id: observation_id)
    consultation = OgConsultation.find_by(id: og_consultation_id)
    return if observation.nil? || consultation.nil?

    consultation.mark_processing!
    runner = OgConsultations::Kinds.runner_class_for(consultation.kind)
    runner.call(observation: observation, og_consultation: consultation)
  end
end
