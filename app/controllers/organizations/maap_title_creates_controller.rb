# frozen_string_literal: true

class Organizations::MaapTitleCreatesController < Organizations::OrganizationNamespaceBaseController
  include MaapSimpleCreateProposals

  private

  def proposal_scope
    MaapProposal.title_creates
  end

  def payload_class
    MaapProposals::TitlePayload
  end

  def apply_service
    MaapProposals::ApplyTitleCreate
  end

  def resource_label
    "Title"
  end

  def show_path_helper
    :organization_maap_title_create_path
  end
end
