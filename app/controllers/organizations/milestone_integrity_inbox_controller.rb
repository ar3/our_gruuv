# frozen_string_literal: true

class Organizations::MilestoneIntegrityInboxController < Organizations::OrganizationNamespaceBaseController
  after_action :verify_authorized

  def show
    authorize organization, :milestone_integrity_inbox?

    @sections = MilestoneIntegrityInbox::Builder.call(
      organization: organization,
      viewing_teammate: current_company_teammate
    )
  end
end
