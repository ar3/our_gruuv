# frozen_string_literal: true

class Organizations::MaapTeamCreatesController < Organizations::OrganizationNamespaceBaseController
  include MaapSimpleCreateProposals

  private

  def proposal_scope
    MaapProposal.team_creates
  end

  def payload_class
    MaapProposals::TeamPayload
  end

  def apply_service
    MaapProposals::ApplyTeamCreate
  end

  def resource_label
    "Team"
  end

  def show_path_helper
    :organization_maap_team_create_path
  end
end
