# frozen_string_literal: true

class Organizations::CompanyTeammates::AbilityMilestoneCalibrationsController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates

  helper Organizations::CompanyTeammatesHelper
  helper AbilityMilestoneCalibrationHelper

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :ensure_calibration!
  before_action :authorize_calibration!
  after_action :verify_authorized

  helper_method :view_role, :can_award?

  def show
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @items = @calibration.rateable_items.includes(:ability)
    @ready_items = @calibration.pending_award_items.includes(:ability)
    @history_items = @calibration.history_items.includes(:ability, :awarded_by_teammate)
    @entry_counts = AbilityMilestoneCalibrationAbilitiesCatalog.entry_counts(
      teammate: @teammate,
      organization: organization
    )
    @can_award = can_award?
  end

  def update
    unless rating_side_editable?
      redirect_to ability_milestone_calibration_organization_company_teammate_path(organization, @teammate),
                  alert: 'You cannot edit ratings for this side right now.'
      return
    end

    item = @calibration.items.find(params.require(:item_id))
    if item.awarded_positive?
      redirect_to ability_milestone_calibration_organization_company_teammate_path(organization, @teammate),
                  alert: 'That ability already has a milestone earned.'
      return
    end

    attr = view_role == :employee ? :employee_rating : :manager_rating
    raw = params[:rating]
    raise ArgumentError, 'Choose a Milestone (1-5).' if raw.nil? || raw.to_s.strip == ''

    value = Integer(raw)
    raise ArgumentError, 'Each rating must be Milestone 1 through 5.' unless (1..5).cover?(value)

    item.assign_side_rating!(role: view_role, value: value)

    notice =
      if item.ready_for_review?
        "#{item.ability.display_name}: both ratings are in. Ready to recognize and certify."
      elsif item.other_rated_for?(view_role)
        "#{item.ability.display_name}: your rating is saved. Waiting on the other participant."
      else
        "#{item.ability.display_name}: rating saved."
      end

    redirect_to ability_milestone_calibration_organization_company_teammate_path(organization, @teammate),
                notice: notice
  rescue ArgumentError, ActiveRecord::RecordNotFound => e
    redirect_to ability_milestone_calibration_organization_company_teammate_path(organization, @teammate),
                alert: e.message
  end

  def review
    redirect_to ability_milestone_calibration_organization_company_teammate_path(organization, @teammate)
  end

  def award
    authorize @calibration, :award?

    item = @calibration.items.find(params[:item_id])
    level = params.require(:official_milestone_level)

    result = AbilityMilestoneCalibrationAwardService.call(
      item: item,
      official_level: level,
      certifying_teammate: current_company_teammate,
      created_by_person: current_person,
      organization: organization,
      certification_note: params[:certification_note]
    )

    if result.ok?
      AbilityMilestoneCalibrationEnsureService.call(teammate: @teammate, organization: organization)
      redirect_to ability_milestone_calibration_organization_company_teammate_path(organization, @teammate),
                  notice: award_notice(item.ability, level.to_i)
    else
      redirect_to ability_milestone_calibration_organization_company_teammate_path(organization, @teammate),
                  alert: result.error.to_s
    end
  end

  def reopen
    authorize @calibration, :reopen?

    result = AbilityMilestoneCalibrationEnsureService.reopen_m0_for_rating!(
      calibration: @calibration,
      organization: organization
    )

    if result.ok?
      redirect_to ability_milestone_calibration_organization_company_teammate_path(organization, @teammate),
                  notice: 'Remaining milestone-0 abilities are open for another rating pass.'
    else
      redirect_to ability_milestone_calibration_organization_company_teammate_path(organization, @teammate),
                  alert: result.error.to_s
    end
  end

  private

  def set_teammate
    resolved_id = resolve_teammate_route_id(params[:id])
    @teammate = organization.teammates.find_by(id: resolved_id)
    return if @teammate

    redirect_to organization_path(organization),
                alert: "Unable to find teammate record in #{organization.name}"
  end

  def ensure_calibration!
    return if performed?

    result = AbilityMilestoneCalibrationEnsureService.call(teammate: @teammate, organization: organization)
    unless result.ok?
      redirect_to my_growth_abilities_organization_company_teammate_path(organization, @teammate),
                  alert: result.error.to_s
      return
    end

    @calibration = result.value
  end

  def authorize_calibration!
    return if performed?

    authorize @calibration
  end

  def view_role
    return :employee if current_company_teammate&.id == @teammate.id

    :manager
  end

  def can_award?
    AbilityMilestoneCalibrationPolicy.new(pundit_user, @calibration).award?
  end

  def rating_side_editable?
    view_role == :employee || can_award? || CompanyTeammatePolicy.new(pundit_user, @teammate).manager?
  end

  def award_notice(ability, level)
    if level.positive?
      "#{ability.display_name}: Milestone #{level} earned."
    else
      "#{ability.display_name} left at Milestone 0 (still needs calibration until Milestone 1-5 is recognized and certified)."
    end
  end
end
