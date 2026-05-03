# frozen_string_literal: true

class TeammateGrowthJob < ApplicationJob
  queue_as :default

  def perform(teammate_id, organization_id, maap_agent_run_id)
    teammate = CompanyTeammate.find_by(id: teammate_id)
    organization = Organization.find_by(id: organization_id)
    run = MaapAgentRun.find_by(id: maap_agent_run_id)
    return if teammate.nil? || organization.nil? || run.nil?

    run.update!(status: 'processing')
    Maap::TeammateGrowthRunner.call(teammate: teammate, organization: organization, maap_agent_run: run)
  end
end
