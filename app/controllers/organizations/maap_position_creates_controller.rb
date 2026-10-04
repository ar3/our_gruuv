# frozen_string_literal: true

class Organizations::MaapPositionCreatesController < Organizations::OrganizationNamespaceBaseController
  include MaapSimpleCreateProposals

  private

  def proposal_scope
    MaapProposal.position_creates
  end

  def payload_class
    MaapProposals::PositionPayload
  end

  def apply_service
    MaapProposals::ApplyPositionCreate
  end

  def resource_label
    "Position"
  end

  def show_path_helper
    :organization_maap_position_create_path
  end
end
