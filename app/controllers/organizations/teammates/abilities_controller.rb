class Organizations::Teammates::AbilitiesController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_ability
  after_action :verify_authorized

  def show
    authorize @teammate.person, :view_check_ins?, policy_class: PersonPolicy

    @organization = organization
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

    visibility_query = ObservationVisibilityQuery.new(current_person, organization)
    base = visibility_query.visible_observations
      .joins(:observation_ratings)
      .where(observation_ratings: { rateable_type: "Ability", rateable_id: @ability.id })

    as_observer_ids = base.where(observer_id: @teammate.person_id).pluck(:id)
    as_observed_ids = base.joins(:observees).where(observees: { teammate_id: @teammate.id }).pluck(:id)
    observation_ids = (as_observer_ids + as_observed_ids).uniq

    @observations = Observation.where(id: observation_ids)
      .includes(:observer, { observed_teammates: :person }, :observation_ratings, :notifications)
      .order(observed_at: :desc)

    preload_rateables_for_observations(@observations)
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:teammate_id])
  end

  def set_ability
    ability_id = params[:id].to_s.split("-").first
    @ability = organization.abilities.unarchived.find_by(id: ability_id)
    raise ActiveRecord::RecordNotFound unless @ability
  end

  def preload_rateables_for_observations(observations)
    rating_ids_by_type = observations.flat_map(&:observation_ratings).group_by(&:rateable_type)
    rating_ids_by_type.each do |rateable_type, ratings|
      ids = ratings.map(&:rateable_id).uniq
      next if ids.empty?

      case rateable_type
      when "Assignment"
        Assignment.where(id: ids).load
      when "Ability"
        Ability.where(id: ids).load
      when "Aspiration"
        Aspiration.where(id: ids).load
      end
    end
  end
end
