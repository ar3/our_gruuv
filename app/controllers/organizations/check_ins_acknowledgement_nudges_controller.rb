# frozen_string_literal: true

class Organizations::CheckInsAcknowledgementNudgesController < Organizations::OrganizationNamespaceBaseController
  include Organizations::CheckInsHealthTeammateFiltering

  before_action :require_authentication
  after_action :verify_authorized
  helper_method :can_view_check_ins_health_by_manager?

  def index
    authorize @organization, :check_ins_health?
    apply_filter_default_if_needed
    active_teammates = filtered_teammates_for_check_ins_health.to_a
    teammate_ids = active_teammates.map(&:id)
    pending_counts = CheckIns::AcknowledgementQueue.pending_counts_by_teammate_id(teammate_ids: teammate_ids)

    all_rows = active_teammates.map do |teammate|
      pending_count = pending_counts[teammate.id].to_i
      last_nudge = teammate.last_delivered_acknowledgement_nudge
      {
        teammate: teammate,
        person: teammate.person,
        has_pending_ack: pending_count.positive?,
        pending_count: pending_count,
        last_nudge_notification: last_nudge
      }
    end

    needing_ack = all_rows.count { |r| r[:has_pending_ack] }
    @spotlight_stats = {
      total_employees: all_rows.count,
      needing_acknowledgement: needing_ack,
      all_clear: all_rows.count - needing_ack
    }

    @pagy = Pagy.new(count: all_rows.count, page: params[:page] || 1, items: 25)
    @rows = all_rows[@pagy.offset, @pagy.items] || []
    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = available_check_ins_health_manager_filter_options
  end

  def create
    authorize @organization, :check_ins_health?
    apply_filter_default_if_needed
    teammate = filtered_teammates_for_check_ins_health.find_by(id: resolve_teammate_route_id(params[:company_teammate_id]))
    unless teammate
      redirect_to redirect_index_path, alert: "Teammate not found or not in this view."
      return
    end

    result = CheckIns::AcknowledgementNudgeService.call(
      organization: @organization,
      employee_teammate: teammate,
      nudger_company_teammate: current_company_teammate
    )

    if result.ok?
      redirect_to redirect_index_path, notice: "Nudge sent."
    else
      redirect_to redirect_index_path, alert: result.error
    end
  end

  private

  def redirect_index_path
    organization_check_ins_acknowledgement_nudges_path(
      @organization,
      { manager_id: params[:manager_id], page: params[:page] }.compact_blank
    )
  end

  def can_view_check_ins_health_by_manager?
    policy(@organization).manage_employment? || current_company_teammate&.has_direct_reports?
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access this page."
  end
end
