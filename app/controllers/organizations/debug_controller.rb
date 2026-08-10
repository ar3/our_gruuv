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

  def set_employment_end_date
    authorize @organization, :manage_employment?

    teammate = @organization.teammates.find_by(id: params[:teammate_id])
    unless teammate
      redirect_to organization_debug_path(@organization), alert: "Teammate not found."
      return
    end

    result = Organizations::Debug::SetEmploymentEndDateService.call(
      organization: @organization,
      teammate: teammate,
      end_date: params[:end_date],
      created_by: current_company_teammate
    )

    if result.ok?
      redirect_to organization_debug_path(@organization),
                  notice: "Set employment end date for #{teammate.person.display_name} to #{params[:end_date]}."
    else
      redirect_to organization_debug_path(@organization), alert: result.error
    end
  end

  private

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access Debug."
  end
end
