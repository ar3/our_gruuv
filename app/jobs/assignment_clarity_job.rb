# frozen_string_literal: true

class AssignmentClarityJob < ApplicationJob
  queue_as :default

  def perform(assignment_id, og_consultation_id)
    assignment = Assignment.find_by(id: assignment_id)
    consultation = OgConsultation.find_by(id: og_consultation_id)
    return if assignment.nil? || consultation.nil?

    consultation.mark_processing!
    Maap::AssignmentClarityRunner.call(assignment: assignment, og_consultation: consultation)
  end
end
