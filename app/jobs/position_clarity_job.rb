# frozen_string_literal: true

class PositionClarityJob < ApplicationJob
  queue_as :default

  def perform(position_id, og_consultation_id)
    position = Position.find_by(id: position_id)
    consultation = OgConsultation.find_by(id: og_consultation_id)
    return if position.nil? || consultation.nil?

    consultation.mark_processing!
    Maap::PositionClarityRunner.call(position: position, og_consultation: consultation)
  end
end
