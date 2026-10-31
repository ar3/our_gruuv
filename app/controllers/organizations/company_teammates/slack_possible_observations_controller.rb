# frozen_string_literal: true

class Organizations::CompanyTeammates::SlackPossibleObservationsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_slack_possible_observation
  after_action :verify_authorized

  def dismiss
    authorize @slack_possible_observation, :dismiss?

    @slack_possible_observation.dismiss!(by: current_company_teammate)
    redirect_to ogos_source_from_slack_organization_company_teammate_path(
      organization,
      @teammate
    ), notice: "Slack moment dismissed."
  end

  private

  def set_teammate
    @teammate = find_organization_teammate!(params[:company_teammate_id])
  end

  def set_slack_possible_observation
    @slack_possible_observation = SlackPossibleObservation.find(params[:id])
    unless @slack_possible_observation.subject_company_teammate_id == @teammate.id &&
           @slack_possible_observation.organization_id == organization.id
      raise ActiveRecord::RecordNotFound
    end
  end
end
