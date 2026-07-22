# frozen_string_literal: true

class Organizations::ProtectFlowController < Organizations::OrganizationNamespaceBaseController
  include Organizations::ProtectFlowTeammateFiltering

  before_action :require_authentication
  before_action :set_manager_teammate
  before_action :apply_protect_flow_filter_default_if_needed

  def show
    authorize @organization, :protect_flow?

    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = available_protect_flow_manager_filter_options
    teammates = filtered_teammates_for_protect_flow.to_a

    store = ProtectFlow::WeekSnapshotStore.for(person: current_person, organization: @organization)
    @plan = ProtectFlow::PlanBuilder.call(
      organization: @organization,
      week_store: store,
      teammates: teammates,
      week_start: params[:week_start].presence
    )
  end

  private

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access Protect Flow."
  end

  def set_manager_teammate
    @manager_teammate = current_company_teammate
  end
end
