# frozen_string_literal: true

class Organizations::Teammates::Abilities::MilestoneAwardsController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :set_ability
  before_action :set_milestone_award
  after_action :verify_authorized

  def show
    authorize @milestone_award
    load_show_context
  end

  def cosign
    authorize @milestone_award, :cosign?

    result = MilestoneAwards::CosignService.call(
      milestone_award: @milestone_award,
      cosigning_teammate: current_company_teammate,
      typed_name: params[:typed_name],
      reason: params[:reason]
    )

    if result.ok?
      primary = result.value.primary_teammate_milestone
      if primary
        redirect_to organization_teammate_milestone_path(organization, primary),
                    notice: "Co-signed. Milestone award is complete."
      else
        redirect_to award_path(result.value), notice: "Co-signed."
      end
    else
      redirect_to award_path(@milestone_award), alert: result.error.to_s
    end
  end

  def decline
    authorize @milestone_award, :decline?

    result = MilestoneAwards::DeclineCosignService.call(
      milestone_award: @milestone_award,
      invitee_teammate: current_company_teammate,
      reason: params[:reason]
    )

    if result.ok?
      redirect_to organization_get_shit_done_path(organization),
                  notice: "You declined to co-sign this milestone award."
    else
      redirect_to award_path(@milestone_award), alert: result.error.to_s
    end
  end

  def request_cosign
    authorize @milestone_award, :request_cosign?

    result = MilestoneAwards::RequestCosignAfterModerationService.call(
      milestone_award: @milestone_award,
      awarder_teammate: current_company_teammate,
      cosign_invitee_ids: params[:cosign_invitee_ids]
    )

    if result.ok?
      redirect_to award_path(result.value), notice: "Co-sign requested."
    else
      redirect_to award_path(@milestone_award), alert: result.error.to_s
    end
  end

  def require_cosign
    authorize @milestone_award, :require_cosign?

    result = MilestoneAwards::ModeratorRequireCosignService.call(
      milestone_award: @milestone_award,
      moderator_teammate: current_company_teammate
    )

    if result.ok?
      redirect_to organization_milestone_integrity_inbox_path(organization),
                  notice: "Awarder must obtain a co-sign before this milestone counts again."
    else
      redirect_to award_path(@milestone_award), alert: result.error.to_s
    end
  end

  private

  def set_teammate
    @teammate = find_organization_teammate!(params[:teammate_id])
  end

  def set_ability
    company = organization.root_company || organization
    @ability = Ability.find_by!(id: params[:ability_id], company: company)
  end

  def set_milestone_award
    @milestone_award = MilestoneAward
      .includes(cosign_invites: { invitee_teammate: :person }, cosigning_teammate: :person, certifying_teammate: :person)
      .where(teammate_id: @teammate.id, ability_id: @ability.id)
      .find(params[:id])
  end

  def award_path(award)
    organization_teammate_ability_milestone_award_path(
      organization,
      award.teammate,
      award.ability,
      award
    )
  end

  def load_show_context
    @organization = organization
    @recipient = @milestone_award.teammate
    assign_viewable_teammates_context!(selected_teammate: @teammate)

    relevant_abilities = RelevantAbilitiesQuery.new(teammate: @teammate, organization: organization).call.map { |h| h[:ability] }
    @abilities_for_switcher = (relevant_abilities + [@ability]).uniq.sort_by(&:name)

    @evidence = MilestoneAwards::EvidenceQuery.call(
      organization: organization,
      viewer_person: current_person,
      viewing_teammate: current_company_teammate,
      teammate: @recipient,
      ability: @ability
    )
    @milestone_description = @ability.milestone_description(@milestone_award.official_milestone_level)

    if policy(@milestone_award).request_cosign?
      @cosign_candidate_groups = MilestoneAwards::CosignCandidatesQuery.call(
        organization: organization,
        recipient: @recipient,
        awarder: @milestone_award.certifying_teammate,
        ability: @ability,
        official_level: @milestone_award.official_milestone_level
      )
    end
  end
end
