# frozen_string_literal: true

class AbilityClarityJob < ApplicationJob
  queue_as :default

  def perform(ability_id, og_consultation_id)
    ability = Ability.find_by(id: ability_id)
    consultation = OgConsultation.find_by(id: og_consultation_id)
    return if ability.nil? || consultation.nil?

    consultation.mark_processing!
    runner = OgConsultations::Kinds.runner_class_for(consultation.kind)
    runner.call(ability: ability, og_consultation: consultation)
  end
end
