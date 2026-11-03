# frozen_string_literal: true

class Organizations::CompanyTeammates::SlackPossibleObservationsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_slack_possible_observation
  after_action :verify_authorized

  def dismiss
    authorize @slack_possible_observation, :dismiss?

    @slack_possible_observation.dismiss!(by: current_company_teammate)
    redirect_to after_action_path, notice: "Slack moment dismissed as not OGO-worthy."
  end

  def promote
    authorize @slack_possible_observation, :promote?

    result = PossibleObservationSlackSearches::PromoteSlackPossibleObservation.call(
      moment: @slack_possible_observation,
      creator: current_company_teammate
    )

    unless result.ok?
      redirect_to after_action_path, alert: result.error.presence || "Could not promote to OGO."
      return
    end

    notice =
      if result.already_draft
        "A draft OGO already exists for this moment — open it from the list to finish publishing."
      else
        "Draft OGO created. Open draft / Finish publishing from the list when ready."
      end
    redirect_to after_action_path, notice: notice
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

  def after_action_path
    return_to = params[:return_to].to_s
    if return_to.present? && return_to.start_with?("/")
      return_to
    else
      ogos_source_from_slack_organization_company_teammate_path(organization, @teammate)
    end
  end
end
