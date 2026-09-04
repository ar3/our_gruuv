# frozen_string_literal: true

class Organizations::AbilitiesHealthController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  SCORING_COMING_SOON = "Ability Expectation Alignment scoring is coming soon."

  def index
    authorize @organization, :abilities_health?
    @overview = overview_service.call
  end

  def refresh
    authorize @organization, :abilities_health?

    ability = find_active_ability(params[:ability_id])
    unless ability
      redirect_back fallback_location: organization_abilities_health_path(@organization),
                    alert: "Could not refresh: ability not found."
      return
    end

    redirect_back fallback_location: organization_abilities_health_path(@organization),
                  notice: SCORING_COMING_SOON
  end

  def refresh_missing_and_stale
    authorize @organization, :abilities_health?

    redirect_to organization_abilities_health_path(@organization), notice: SCORING_COMING_SOON
  end

  private

  def overview_service
    @overview_service ||= AbilitiesHealth::ExpectationAlignmentOverview.new(organization: @organization)
  end

  def find_active_ability(ability_id)
    Ability.unarchived.for_company(@organization).find_by(id: ability_id)
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access this page."
  end
end
