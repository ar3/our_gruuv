class Organizations::GoalsHealthController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def index
    authorize @organization, :goals_health?
    apply_filter_default_if_needed

    data = goals_health_spotlight_service.rows_and_spotlight_for(params[:manager_id])
    all_rows = data[:rows]
    @spotlight_stats = data[:spotlight_stats]

    @pagy = Pagy.new(count: all_rows.count, page: params[:page] || 1, items: 25)
    @employee_rows = all_rows[@pagy.offset, @pagy.items]
    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = goals_health_spotlight_service.available_manager_filter_options
    assign_goals_health_nudge_context!(spotlight_stats: @spotlight_stats)
  end

  def nudge
    authorize @organization, :goals_health?
    apply_filter_default_if_needed

    manager = resolve_concrete_manager_teammate(params[:manager_id])
    unless manager
      redirect_to organization_goals_health_path(@organization, manager_id: params[:manager_id]),
                  alert: "Select a specific manager to send a Goals Health nudge."
      return
    end

    spotlight_stats = goals_health_spotlight_service.rows_and_spotlight_for(params[:manager_id])[:spotlight_stats]
    result = Goals::HealthNudgeService.call(
      organization: @organization,
      manager_teammate: manager,
      nudger_company_teammate: current_company_teammate,
      spotlight_stats: spotlight_stats,
      recipient_scope: params[:recipient_scope]
    )

    if result.ok?
      redirect_to organization_goals_health_path(@organization, manager_id: params[:manager_id]),
                  notice: "Goals Health nudge sent."
    else
      redirect_to organization_goals_health_path(@organization, manager_id: params[:manager_id]),
                  alert: result.error
    end
  end

  def export
    authorize @organization, :goals_health?
    apply_filter_default_if_needed
    teammates = goals_health_spotlight_service.filtered_teammates(params[:manager_id]).to_a
    visible_goals_by_teammate = build_visible_goals_by_teammate(teammates)
    bucket_lookup = Goals::HealthGoalBucketLookup.load_for_goal_ids(visible_goals_by_teammate.values.flatten.map(&:id))
    csv_content = GoalsHealthGoalsCsvBuilder.new(@organization, visible_goals_by_teammate, bucket_lookup: bucket_lookup).call
    filename = "goals_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    send_data csv_content, filename: filename, type: "text/csv", disposition: "attachment"
  end

  def export_employee_summary
    authorize @organization, :goals_health?
    apply_filter_default_if_needed
    teammates = goals_health_spotlight_service.filtered_teammates(params[:manager_id]).to_a
    aggregate_goals_by_teammate = goals_health_spotlight_service.build_aggregate_goals_by_teammate(teammates)
    csv_content = GoalsHealthEmployeeSummaryCsvBuilder.new(
      aggregate_goals_by_teammate,
      organization: @organization
    ).call
    filename = "employee_goals_summary_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    send_data csv_content, filename: filename, type: "text/csv", disposition: "attachment"
  end

  private

  def goals_health_spotlight_service
    @goals_health_spotlight_service ||= GoalsHealthSpotlightService.new(
      organization: @organization,
      current_person: current_person,
      current_company_teammate: current_company_teammate,
      manage_employment: policy(@organization).manage_employment?
    )
  end

  def apply_filter_default_if_needed
    return if params[:manager_id].present?

    params[:manager_id] = goals_health_spotlight_service.default_manager_filter_value
  end

  def assign_goals_health_nudge_context!(spotlight_stats:)
    @goals_health_nudge_manager = resolve_concrete_manager_teammate(params[:manager_id])
    return unless @goals_health_nudge_manager

    @goals_health_nudge_skip_level = Goals::HealthNudgeService.skip_level_for(
      manager_teammate: @goals_health_nudge_manager,
      organization: @organization
    )
    @goals_health_nudge_recipients_manager = Goals::HealthNudgeService.recipient_teammates(
      manager_teammate: @goals_health_nudge_manager,
      nudger_company_teammate: current_company_teammate,
      organization: @organization,
      recipient_scope: "manager"
    )
    @goals_health_nudge_recipients_manager_and_skip = Goals::HealthNudgeService.recipient_teammates(
      manager_teammate: @goals_health_nudge_manager,
      nudger_company_teammate: current_company_teammate,
      organization: @organization,
      recipient_scope: "manager_and_skip"
    )
    @goals_health_nudge_message = Goals::HealthNudgeMessage.new(
      organization: @organization,
      manager_teammate: @goals_health_nudge_manager,
      spotlight_stats: spotlight_stats
    )
    @last_goals_health_nudge = Goals::HealthNudgeService.last_delivered_for(
      manager_teammate: @goals_health_nudge_manager
    )
  end

  def resolve_concrete_manager_teammate(manager_id)
    return nil unless manager_id.to_s =~ /\ACompanyTeammate_(\d+)\z/

    mgr_id = Regexp.last_match(1).to_i
    return nil unless goals_health_spotlight_service.manager_filter_viewable?(mgr_id)

    CompanyTeammate.for_organization_hierarchy(@organization).find_by(id: mgr_id)
  end

  def build_visible_goals_by_teammate(teammates)
    teammate_ids = teammates.map(&:id)
    goals = policy_scope(Goal)
      .where(owner_type: "CompanyTeammate", owner_id: teammate_ids, deleted_at: nil)
      .includes(:goal_check_ins, creator: :person)
      .to_a

    goals_by_teammate_id = goals.group_by(&:owner_id)
    teammates.each_with_object({}) do |teammate, hash|
      hash[teammate] = Array(goals_by_teammate_id[teammate.id]).select { |goal| goal.can_be_viewed_by?(current_person) }
    end
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access this page."
  end
end
