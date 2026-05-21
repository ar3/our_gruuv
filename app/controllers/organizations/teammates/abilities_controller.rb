class Organizations::Teammates::AbilitiesController < Organizations::OrganizationNamespaceBaseController
  include Organizations::LoadAssociableGoalsDisplay
  include Organizations::AssignsViewableTeammates

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_ability
  after_action :verify_authorized

  def show
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy

    @organization = organization
    assign_viewable_teammates_context!(selected_teammate: @teammate)

    @teammate_milestones = @teammate.teammate_milestones
      .where(ability: @ability)
      .includes(:certifying_teammate)
      .order(:milestone_level, :attained_at)

    award_query = TeammateMilestoneRecipientEligibilityQuery.new(
      awarding_teammate: current_company_teammate,
      organization: organization
    )
    @can_award_milestone = award_query.eligible_to_award?(@teammate)
    @award_milestone_disabled_reason = award_query.ineligibility_explanation(@teammate) unless @can_award_milestone

    @award_milestone_url = new_organization_teammate_milestone_path(
      organization,
      teammate_id: @teammate.id,
      ability_id: @ability.id,
      return_url: request.original_url
    )

    relevant_abilities = RelevantAbilitiesQuery.new(teammate: @teammate, organization: organization).call.map { |h| h[:ability] }
    @abilities_for_switcher = (relevant_abilities + [@ability]).uniq.sort_by(&:name)

    ability_show_return_path = organization_teammate_ability_path(organization, @teammate, @ability)
    latest_milestone = @teammate_milestones.max_by(&:attained_at)
    since_date = latest_milestone&.attained_at || 10.years.ago
    @observations_since_date = since_date
    @observations_has_finalized_check_in = latest_milestone.present?
    observations_params = {
      observee_ids: [@teammate.id],
      rateable_type: "Ability",
      rateable_id: @ability.id,
      timeframe: "between",
      timeframe_start_date: since_date.to_date.to_s,
      timeframe_end_date: Time.current.to_date.to_s
    }
    observations_query = ObservationsQuery.new(organization, observations_params, current_person: current_person)
    @observations_since_finalized = observations_query.call
      .joins(:observation_ratings)
      .where(observation_ratings: { rateable_type: "Ability", rateable_id: @ability.id })
      .distinct
      .includes(:observer, :observed_teammates, :observation_ratings)
      .order(observed_at: :desc)
      .limit(50)

    preload_rateables_for_observations(@observations_since_finalized)

    @observations_involving_url = organization_observations_path(
      organization,
      observee_ids: [@teammate.id],
      rateable_type: "Ability",
      rateable_id: @ability.id,
      return_url: ability_show_return_path,
      return_text: "Back to 1-by-1 check-in"
    )
    @observations_new_observation_url = new_organization_observation_path(
      organization,
      observee_ids: [@teammate.id],
      rateable_type: "Ability",
      rateable_id: @ability.id,
      return_url: ability_show_return_path,
      return_text: "Back to 1-by-1 check-in"
    )

    load_associable_goals_display!(@ability, subject_teammate: @teammate)
  end

  private

  def set_teammate
    @teammate = find_organization_teammate!(params[:teammate_id])
  end

  def set_ability
    ability_id = params[:id].to_s.split("-").first
    @ability = organization.abilities.unarchived.find_by(id: ability_id)
    raise ActiveRecord::RecordNotFound unless @ability
  end
end
