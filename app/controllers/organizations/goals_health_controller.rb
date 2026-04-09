class Organizations::GoalsHealthController < Organizations::OrganizationNamespaceBaseController
  before_action :require_authentication
  after_action :verify_authorized

  def index
    authorize @organization, :goals_health?
    apply_filter_default_if_needed

    active_teammates = filtered_teammates_for_goals_health.to_a
    @aggregate_goals_by_teammate = build_aggregate_goals_by_teammate(active_teammates)

    all_goal_ids = @aggregate_goals_by_teammate.values.flatten.map(&:id)
    bucket_lookup = Goals::HealthGoalBucketLookup.load_for_goal_ids(all_goal_ids)
    all_rows = active_teammates.map { |teammate| row_for(teammate, @aggregate_goals_by_teammate[teammate] || [], bucket_lookup) }
    @spotlight_stats = spotlight_stats(all_rows)

    @pagy = Pagy.new(count: all_rows.count, page: params[:page] || 1, items: 25)
    @employee_rows = all_rows[@pagy.offset, @pagy.items]
    @current_manager_filter = params[:manager_id]
    @available_manager_filter_options = available_goals_health_manager_filter_options
  end

  def export
    authorize @organization, :goals_health?
    apply_filter_default_if_needed
    teammates = filtered_teammates_for_goals_health.to_a
    visible_goals_by_teammate = build_visible_goals_by_teammate(teammates)
    bucket_lookup = Goals::HealthGoalBucketLookup.load_for_goal_ids(visible_goals_by_teammate.values.flatten.map(&:id))
    csv_content = GoalsHealthGoalsCsvBuilder.new(@organization, visible_goals_by_teammate, bucket_lookup: bucket_lookup).call
    filename = "goals_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    send_data csv_content, filename: filename, type: "text/csv", disposition: "attachment"
  end

  def export_employee_summary
    authorize @organization, :goals_health?
    apply_filter_default_if_needed
    teammates = filtered_teammates_for_goals_health.to_a
    aggregate_goals_by_teammate = build_aggregate_goals_by_teammate(teammates)
    bucket_lookup = Goals::HealthGoalBucketLookup.load_for_goal_ids(aggregate_goals_by_teammate.values.flatten.map(&:id))
    csv_content = GoalsHealthEmployeeSummaryCsvBuilder.new(aggregate_goals_by_teammate, bucket_lookup: bucket_lookup).call
    filename = "employee_goals_summary_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
    send_data csv_content, filename: filename, type: "text/csv", disposition: "attachment"
  end

  private

  def row_for(teammate, goals, bucket_lookup)
    buckets = bucket_lookup.partition(goals)
    {
      teammate: teammate,
      person: teammate.person,
      manager: Goals::HealthManagerPerson.for(teammate),
      manager_teammate: Goals::HealthManagerPerson.manager_teammate_for(teammate),
      status: Goals::HealthStatusCalculator.call(goals),
      associated_goals: buckets[:associated],
      unassociated_goals: buckets[:unassociated],
      child_goals: buckets[:child],
      associated: status_and_counts(buckets[:associated]),
      unassociated: status_and_counts(buckets[:unassociated]),
      child: status_and_counts(buckets[:child])
    }
  end

  def status_and_counts(goals)
    {
      status: Goals::HealthStatusCalculator.call(goals),
      draft: goals.count { |goal| goal.completed_at.nil? && goal.started_at.nil? },
      active: goals.count { |goal| goal.completed_at.nil? && goal.started_at.present? },
      completed: goals.count { |goal| goal.completed_at.present? }
    }
  end

  def build_aggregate_goals_by_teammate(teammates)
    teammate_ids = teammates.map(&:id)
    goals = Goal
      .where(owner_type: "CompanyTeammate", owner_id: teammate_ids, deleted_at: nil)
      .includes(:goal_check_ins, creator: :person)
      .to_a

    goals_by_teammate_id = goals.group_by(&:owner_id)
    teammates.each_with_object({}) do |teammate, hash|
      hash[teammate] = Array(goals_by_teammate_id[teammate.id])
    end
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

  def spotlight_stats(rows)
    total_employees = rows.count
    healthy_count = rows.count { |row| row[:status] == :healthy }
    ok_count = rows.count { |row| row[:status] == :ok }
    concerning_count = rows.count { |row| row[:status] == :concerning }
    concerning_pct = total_employees.positive? ? ((concerning_count.to_f / total_employees) * 100).round(1) : 0.0

    {
      total_employees: total_employees,
      healthy_count: healthy_count,
      ok_count: ok_count,
      concerning_count: concerning_count,
      concerning_pct: concerning_pct
    }
  end

  def apply_filter_default_if_needed
    return if params[:manager_id].present?

    params[:manager_id] = default_manager_filter_value
  end

  def default_manager_filter_value
    if policy(@organization).manage_employment?
      "everyone"
    elsif current_company_teammate&.has_direct_reports?
      "my_direct_employees"
    elsif current_company_teammate && hierarchy_count_excluding_self > 0
      "my_employees_full_hierarchy"
    else
      "just_me"
    end
  end

  def hierarchy_count_excluding_self
    return 0 unless current_company_teammate && @organization

    ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
    ids.size > 1 ? ids.size - 1 : 0
  end

  def filtered_teammates_for_goals_health
    base_scope = CompanyTeammate.for_organization_hierarchy(@organization)
      .where.not(first_employed_at: nil)
      .where(last_terminated_at: nil)
      .includes(:person, :organization, employment_tenures: { manager_teammate: :person })
      .joins(:person)
      .order("people.last_name ASC, people.first_name ASC")

    case params[:manager_id].to_s
    when "everyone"
      return base_scope if policy(@organization).manage_employment?

      viewing_teammate = base_scope.find_by(person: current_person)
      if viewing_teammate
        hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(viewing_teammate, @organization).pluck(:id)
        base_scope.where(id: hierarchy_ids)
      else
        base_scope.none
      end
    when "my_direct_employees"
      return base_scope.none unless current_company_teammate&.has_direct_reports?

      direct_report_ids = EmploymentTenure
        .where(company: @organization, manager_teammate: current_company_teammate, ended_at: nil)
        .pluck(:teammate_id)
      base_scope.where(id: direct_report_ids)
    when "my_employees_full_hierarchy"
      return base_scope.none unless current_company_teammate

      hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
      base_scope.where(id: hierarchy_ids)
    when "just_me"
      return base_scope.none unless current_company_teammate

      base_scope.where(id: current_company_teammate.id)
    else
      if params[:manager_id].to_s =~ /\ACompanyTeammate_(\d+)\z/
        manager_id = Regexp.last_match(1).to_i
        return base_scope.none unless manager_viewable?(manager_id)

        direct_report_ids = EmploymentTenure
          .where(company: @organization, manager_teammate_id: manager_id, ended_at: nil)
          .pluck(:teammate_id)
        base_scope.where(id: direct_report_ids)
      else
        params[:manager_id] = default_manager_filter_value
        filtered_teammates_for_goals_health
      end
    end
  end

  def manager_viewable?(manager_id)
    return true if policy(@organization).manage_employment?
    return false unless current_company_teammate

    hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
    hierarchy_ids.include?(manager_id)
  end

  def available_goals_health_manager_filter_options
    company = @organization.root_company || @organization
    options = []
    options << ["Everyone", "everyone"] if policy(@organization).manage_employment?
    options << ["My Direct Employees", "my_direct_employees"] if current_company_teammate&.has_direct_reports?
    options << ["My Employees (full hierarchy)", "my_employees_full_hierarchy"] if current_company_teammate && hierarchy_count_excluding_self > 0
    options << ["Just Me", "just_me"]
    options.concat(visible_managers_for_goals_health(company))
    options
  end

  def visible_managers_for_goals_health(company)
    if policy(@organization).manage_employment?
      manager_teammate_ids = EmploymentTenure
        .where(company: company, ended_at: nil)
        .where.not(manager_teammate_id: nil)
        .distinct
        .pluck(:manager_teammate_id)
    else
      return [] unless current_company_teammate

      hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, @organization).pluck(:id)
      manager_teammate_ids = EmploymentTenure
        .where(company: company, ended_at: nil, manager_teammate_id: hierarchy_ids)
        .where.not(manager_teammate_id: nil)
        .distinct
        .pluck(:manager_teammate_id)
    end

    teammates = CompanyTeammate.where(id: manager_teammate_ids).joins(:person).order("people.last_name ASC", "people.first_name ASC")
    teammates.map { |teammate| ["Manager: #{teammate.person&.display_name}", "CompanyTeammate_#{teammate.id}"] }.reject { |pair| pair[0].blank? }
  end

  def require_authentication
    return if current_person

    redirect_to root_path, alert: "Please log in to access this page."
  end
end
