# frozen_string_literal: true

class Organizations::SlackPogoAutoRefreshHubsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  after_action :verify_authorized

  def create
    authorize PossibleObservationSlackSearch, :index?
    result = SlackPogoAutoRefresh::SyncHub.enable(runner: current_company_teammate)
    redirect_after_hub(result, notice: "Auto-refresh on for you and your direct reports (every 14 days).")
  end

  def destroy
    authorize PossibleObservationSlackSearch, :index?
    result = SlackPogoAutoRefresh::SyncHub.disable(runner: current_company_teammate)
    redirect_after_hub(result, notice: "Hub auto-refresh turned off. Independently opted-in people stay on.")
  end

  private

  def redirect_after_hub(result, notice:)
    if result.needs_slack_oauth
      redirect_to organization_company_teammate_slack_search_oauth_authorize_path(
        organization,
        current_company_teammate,
        source: "slackPogoAutoRefreshHub",
        return_to: organization_possible_observation_consults_path(organization)
      )
      return
    end

    unless result.ok?
      redirect_to organization_possible_observation_consults_path(organization), alert: result.error
      return
    end

    redirect_to organization_possible_observation_consults_path(organization), notice: notice
  end
end
