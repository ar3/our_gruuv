# frozen_string_literal: true

class Organizations::ProtectFlowController < Organizations::OrganizationNamespaceBaseController
  include Organizations::ProtectFlowTeammateFiltering
  include Organizations::HealthNudgeActions

  before_action :require_authentication
  before_action :set_manager_teammate
  before_action :apply_protect_flow_filter_default_if_needed, unless: :protect_flow_self_only?

  def show
    authorize @organization, :protect_flow?

    @protect_flow_self_only = protect_flow_self_only?
    @current_manager_filter = @protect_flow_self_only ? "just_me" : params[:manager_id]
    @available_manager_filter_options = available_protect_flow_manager_filter_options unless @protect_flow_self_only
    load_protect_flow_plan!
    return if @protect_flow_self_only

    stats = HealthNudges::Service.spotlight_stats_from_protect_flow_plan(@plan)
    assign_health_nudge_context!(
      health_object: "protect_flow",
      spotlight_stats: stats
    )
    assign_protect_flow_nudge_draft!(spotlight_stats: stats)
  end

  def nudge
    authorize @organization, :protect_flow?
    if protect_flow_self_only?
      redirect_to organization_protect_flow_path(@organization),
                  alert: "Health nudges are for managers with direct reports."
      return
    end

    load_protect_flow_plan!
    redirect_params = { manager_id: params[:manager_id] }
    redirect_params[:week_start] = params[:week_start] if params[:week_start].present?
    perform_health_nudge!(
      health_object: "protect_flow",
      spotlight_stats: HealthNudges::Service.spotlight_stats_from_protect_flow_plan(@plan),
      employee_entries: HealthNudges::EmployeeEntries.from_protect_flow_people(@plan[:people]),
      people: @plan[:people],
      redirect_path: organization_protect_flow_path(@organization, **redirect_params)
    )
  end

  private

  def protect_flow_self_only?
    return true unless current_company_teammate

    !current_company_teammate.has_direct_reports?
  end

  def load_protect_flow_plan!
    teammates =
      if protect_flow_self_only?
        Array(current_company_teammate)
      else
        filtered_teammates_for_protect_flow.to_a
      end
    store = ProtectFlow::WeekSnapshotStore.for(person: current_person, organization: @organization)
    @plan = ProtectFlow::PlanBuilder.call(
      organization: @organization,
      week_store: store,
      teammates: teammates,
      week_start: params[:week_start].presence,
      viewer: current_company_teammate
    )
  end

  def require_authentication
    return if current_person

    redirect_unauthenticated_to_login!(message: "Please log in to access Protect Flow.", flash_key: :alert)
  end

  def set_manager_teammate
    @manager_teammate = current_company_teammate
  end

  def health_nudge_manager_filter_viewable?(manager_id)
    protect_flow_manager_viewable?(manager_id)
  end

  def assign_protect_flow_nudge_draft!(spotlight_stats:)
    return unless @health_nudge_manager && @health_nudge_message

    store = HealthNudges::DraftStore.for(
      person: current_person,
      organization: @organization,
      manager_teammate: @health_nudge_manager
    )
    suggested = HealthNudges::SuggestedBody.call(
      message: @health_nudge_message,
      people: @plan[:people]
    )
    @health_nudge_draft = store.ensure_suggested!(suggested)
    @health_nudge_suggested_body = @health_nudge_draft["suggested_body"].presence || suggested
    @health_nudge_og_consulted_body = @health_nudge_draft["og_consulted_body"].presence
    @health_nudge_body = @health_nudge_draft["body"].presence || @health_nudge_suggested_body
    @health_nudge_consultation =
      if @health_nudge_draft["og_consultation_id"].present?
        OgConsultation.find_by(id: @health_nudge_draft["og_consultation_id"])
      end
    @health_nudge_consultation ||= latest_protect_flow_nudge_consultation
  end

  def latest_protect_flow_nudge_consultation
    return nil unless @health_nudge_manager

    OgConsultation
      .where(
        kind: OgConsultation::KIND_PROTECT_FLOW_NUDGE,
        subject: @health_nudge_manager,
        organization: @organization,
        triggered_by_teammate: current_company_teammate
      )
      .where("created_at >= ?", Time.zone.now.beginning_of_day)
      .latest_first
      .first
  end
end
