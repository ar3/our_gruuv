# frozen_string_literal: true

class Organizations::DebugController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def show
    authorize @organization, :manage_employment?

    report = Organizations::Debug::IntegrityReportService.call(organization: @organization)
    @slack_configured = report[:slack_configured]
    @sections = report[:sections]
  end

  private

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access Debug."
  end
end
