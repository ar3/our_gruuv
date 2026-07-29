# frozen_string_literal: true

class PositionChangeEligibilityJob < ApplicationJob
  queue_as :default

  def perform(teammate_id, position_id, organization_id, og_consultation_id)
    teammate = CompanyTeammate.find_by(id: teammate_id)
    position = Position.find_by(id: position_id)
    organization = Organization.find_by(id: organization_id)
    consultation = OgConsultation.find_by(id: og_consultation_id)
    return if teammate.nil? || position.nil? || organization.nil? || consultation.nil?

    consultation.mark_processing!
    Maap::PositionChangeEligibilityRunner.call(
      teammate: teammate,
      position: position,
      organization: organization,
      og_consultation: consultation
    )
  end
end
