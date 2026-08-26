# frozen_string_literal: true

class Organizations::ProtectFlowController < Organizations::OrganizationNamespaceBaseController
  include Organizations::ProtectFlowTeammateFiltering
  include Organizations::HealthNudgeActions

  before_action :require_authentication
  before_action :set_manager_teammate
  before_action :apply_protect_flow_filter_default_if_needed

  def show
    authorize @organization, :protect_flow?

    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = available_protect_flow_manager_filter_options
    load_protect_flow_plan!
    assign_health_nudge_context!(
      health_object: "protect_flow",
      spotlight_stats: HealthNudges::Service.spotlight_stats_from_protect_flow_plan(@plan)
    )
  end

  def nudge
    authorize @organization, :protect_flow?

    load_protect_flow_plan!
    redirect_params = { manager_id: params[:manager_id] }
    redirect_params[:week_start] = params[:week_start] if params[:week_start].present?
    perform_health_nudge!(
      health_object: "protect_flow",
      spotlight_stats: HealthNudges::Service.spotlight_stats_from_protect_flow_plan(@plan),
      redirect_path: organization_protect_flow_path(@organization, **redirect_params)
    )
  end

  private

  def load_protect_flow_plan!
    teammates = filtered_teammates_for_protect_flow.to_a
    store = ProtectFlow::WeekSnapshotStore.for(person: current_person, organization: @organization)
    @plan = ProtectFlow::PlanBuilder.call(
      organization: @organization,
      week_store: store,
      teammates: teammates,
      week_start: params[:week_start].presence
    )
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access Protect Flow."
  end

  def set_manager_teammate
    @manager_teammate = current_company_teammate
  end

  def health_nudge_manager_filter_viewable?(manager_id)
    protect_flow_manager_viewable?(manager_id)
  end
end
