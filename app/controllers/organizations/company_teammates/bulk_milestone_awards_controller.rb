# frozen_string_literal: true

class Organizations::CompanyTeammates::BulkMilestoneAwardsController < Organizations::OrganizationNamespaceBaseController
  include Organizations::AssignsViewableTeammates

  helper Organizations::CompanyTeammatesHelper

  before_action :authenticate_person!
  before_action :set_teammate
  before_action :authorize_bulk_milestones
  before_action :ensure_bulk_milestone_new_access!, only: [:new]
  before_action :ensure_eligible_recipient!, only: %i[review create]
  after_action :verify_authorized

  def new
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @bulk_award_recipient_eligible = milestone_eligibility.eligible_to_award?(@teammate)
    @bulk_award_review_disabled_tooltip = milestone_eligibility.ineligibility_explanation(@teammate) unless @bulk_award_recipient_eligible
    @catalog_rows = BulkMilestoneAwardAbilitiesCatalog.call(teammate: @teammate, organization: organization)
    @eligible_teammate_ids = milestone_eligibility.eligible_teammates.pluck(:id).to_set
    @milestones_by_ability_level = bulk_award_milestones_index_for(@catalog_rows)
  end

  def review
    assign_viewable_teammates_context!(selected_teammate: @teammate)
    @catalog_rows = BulkMilestoneAwardAbilitiesCatalog.call(teammate: @teammate, organization: organization)
    @selections = milestone_selections_from_params

    if (msg = validate_selections_complete(@catalog_rows, @selections))
      redirect_to new_bulk_milestone_award_organization_company_teammate_path(organization, @teammate), alert: msg
      return
    end

    @preview_rows = BulkMilestoneAwardApplyService.preview(
      teammate: @teammate,
      catalog_rows: @catalog_rows,
      selections_by_ability_id: @selections
    )
  end

  def create
    @catalog_rows = BulkMilestoneAwardAbilitiesCatalog.call(teammate: @teammate, organization: organization)
    @selections = milestone_selections_from_params

    if (msg = validate_selections_complete(@catalog_rows, @selections))
      redirect_to new_bulk_milestone_award_organization_company_teammate_path(organization, @teammate), alert: msg
      return
    end

    result = BulkMilestoneAwardApplyService.call(
      teammate: @teammate,
      organization: organization,
      selections_by_ability_id: @selections,
      certifying_teammate: current_company_teammate,
      created_by_person: current_person
    )

    if result.ok?
      redirect_to new_bulk_milestone_award_organization_company_teammate_path(organization, @teammate),
                  notice: 'Bulk milestone adjustment was saved.'
    else
      assign_viewable_teammates_context!(selected_teammate: @teammate)
      @preview_rows = BulkMilestoneAwardApplyService.preview(
        teammate: @teammate,
        catalog_rows: @catalog_rows,
        selections_by_ability_id: @selections
      )
      flash.now[:alert] = result.error.to_s
      render :review, status: :unprocessable_entity
    end
  end

  private

  def set_teammate
    @teammate = organization.teammates.find_by(id: params[:id])
    return if @teammate

    redirect_to organization_path(organization),
                alert: "Unable to find teammate record in #{organization.name}"
    return
  end

  def authorize_bulk_milestones
    authorize TeammateMilestone, :create?
  end

  def ensure_bulk_milestone_new_access!
    return if current_company_teammate.blank?

    return if milestone_eligibility.eligible_to_award?(@teammate)
    return if @teammate.id == current_company_teammate.id

    redirect_to celebrate_milestones_organization_path(organization),
                alert: milestone_eligibility.ineligibility_explanation(@teammate)
  end

  def ensure_eligible_recipient!
    return if milestone_eligibility.eligible_to_award?(@teammate)

    redirect_to celebrate_milestones_organization_path(organization),
                alert: milestone_eligibility.ineligibility_explanation(@teammate)
    return
  end

  def milestone_eligibility
    @milestone_eligibility ||= TeammateMilestoneRecipientEligibilityQuery.new(
      awarding_teammate: current_company_teammate,
      organization: organization
    )
  end

  def milestone_selections_from_params
    raw = params[:milestones]
    return {} if raw.blank?

    h = if raw.is_a?(ActionController::Parameters)
          raw.permit!.to_h
        else
          raw.stringify_keys
        end
    h.transform_keys(&:to_i).transform_values { |v| v.to_i }
  end

  def bulk_award_milestones_index_for(catalog_rows)
    ability_ids = catalog_rows.map { |r| r[:ability_id] }
    return {} if ability_ids.empty?

    @teammate.teammate_milestones.where(ability_id: ability_ids).index_by { |m| [m.ability_id, m.milestone_level] }
  end

  def validate_selections_complete(catalog_rows, selections)
    return 'No abilities are available for this teammate.' if catalog_rows.empty?

    required_ids = catalog_rows.map { |r| r[:ability_id] }.to_set
    sel_ids = selections.keys.to_set
    missing = required_ids - sel_ids
    return "Each ability must have a milestone level selected (#{missing.size} missing)." if missing.any?

    extra = sel_ids - required_ids
    return 'Invalid ability in submission.' if extra.any?

    selections.each do |_aid, level|
      return 'Invalid milestone level.' unless (0..5).cover?(level)
    end

    nil
  end
end
