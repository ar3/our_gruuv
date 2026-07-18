# frozen_string_literal: true

class TeammateGrowthJob < ApplicationJob
  queue_as :default

  def perform(teammate_id, organization_id, og_consultation_id)
    teammate = CompanyTeammate.find_by(id: teammate_id)
    organization = Organization.find_by(id: organization_id)
    consultation = OgConsultation.find_by(id: og_consultation_id)
    return if teammate.nil? || organization.nil? || consultation.nil?

    consultation.mark_processing!
    Maap::TeammateGrowthRunner.call(
      teammate: teammate,
      organization: organization,
      og_consultation: consultation
    )
  end
end
