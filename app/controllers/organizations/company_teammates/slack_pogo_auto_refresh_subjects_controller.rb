# frozen_string_literal: true

class Organizations::CompanyTeammates::SlackPogoAutoRefreshSubjectsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_one_on_one_link
  after_action :verify_authorized

  def create
    authorize @one_on_one_link, :ogos?
    result = SlackPogoAutoRefresh::ToggleSubject.call(
      runner: current_company_teammate,
      subject: @teammate,
      enable: true
    )
    redirect_after_toggle(result)
  end

  def destroy
    authorize @one_on_one_link, :ogos?
    result = SlackPogoAutoRefresh::ToggleSubject.call(
      runner: current_company_teammate,
      subject: @teammate,
      enable: false
    )
    redirect_after_toggle(result)
  end

  private

  def set_teammate
    @teammate = find_organization_teammate!(params[:company_teammate_id].presence || params[:id])
  end

  def set_one_on_one_link
    @one_on_one_link = @teammate&.one_on_one_link || OneOnOneLink.new(teammate: @teammate)
  end

  def redirect_after_toggle(result)
    path = ogos_source_from_slack_organization_company_teammate_path(organization, @teammate)

    if result.needs_slack_oauth
      redirect_to organization_company_teammate_slack_search_oauth_authorize_path(
        organization,
        current_company_teammate,
        source: "sourceFromSlackAutoRefresh",
        return_to: path
      )
      return
    end

    unless result.ok?
      redirect_to path, alert: result.error
      return
    end

    notice =
      if result.enabled?
        "Auto-refresh on for #{@teammate.person.casual_name} (every 14 days)."
      else
        "Auto-refresh off for #{@teammate.person.casual_name}."
      end
    redirect_to path, notice: notice
  end
end
