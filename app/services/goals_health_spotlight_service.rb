# frozen_string_literal: true

# Shared goals-health filtering, per-employee rows, and spotlight counts (used by GoalsHealthController and Start Here).
class GoalsHealthSpotlightService
  attr_reader :organization, :current_person, :current_company_teammate, :manage_employment

  def initialize(organization:, current_person:, current_company_teammate:, manage_employment:)
    @organization = organization
    @current_person = current_person
    @current_company_teammate = current_company_teammate
    @manage_employment = manage_employment
  end

  def default_manager_filter_value
    if manage_employment
      "everyone"
    elsif current_company_teammate&.has_direct_reports?
      "my_direct_employees"
    elsif current_company_teammate && hierarchy_count_excluding_self.positive?
      "my_employees_full_hierarchy"
    else
      "just_me"
    end
  end

  # Resolves blank/invalid manager_id to the same default as the Goals Health page.
  def normalize_manager_filter(manager_id)
    mid = manager_id.to_s
    return default_manager_filter_value if mid.blank?
    return mid if %w[everyone my_direct_employees my_employees_full_hierarchy just_me].include?(mid)
    return mid if mid.match?(/\ACompanyTeammate_\d+\z/)

    default_manager_filter_value
  end

  def filtered_teammates(manager_id)
    mid = normalize_manager_filter(manager_id)
    filtered_teammates_for_mid(mid)
  end

  # Unique teammate ids for the filter scope. Use instead of filtered_teammates(...).pluck(:id)
  # when the scope eager-loads employment_tenures — a plain pluck can duplicate rows per tenure.
  def filtered_teammate_ids(manager_id)
    filtered_teammates(manager_id).reorder(nil).distinct.pluck(:id)
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

  def rows_and_spotlight_for(manager_id)
    teammates = filtered_teammates(manager_id).to_a
    aggregate = build_aggregate_goals_by_teammate(teammates)
    all_goals = aggregate.values.flatten
    engagement_health_by_teammate_id = GoalsHealthEngagementHealthSupport.records_by_teammate_id(
      organization: organization,
      teammate_ids: teammates.map(&:id)
    )
    attachment_facts = GoalsHealthAttachmentLookup.load_for_goals(all_goals)

    rows = teammates.map do |tm|
      row_for(
        tm,
        aggregate[tm] || [],
        engagement_health_by_teammate_id[tm.id] || [],
        attachment_facts
      )
    end
    { rows: rows, spotlight_stats: spotlight_stats(rows) }
  end

  # Three-tier counts for Start Here / full-page compact component (ok_count = Warning).
  def compact_spotlight_stats(manager_id)
    stats = rows_and_spotlight_for(manager_id)[:spotlight_stats]
    {
      total_employees: stats[:total_employees],
      healthy_count: stats[:healthy_count],
      ok_count: stats[:warning_count],
      concerning_count: stats[:needs_attention_count]
    }
  end

  def available_manager_filter_options
    company = organization.root_company || organization
    options = []
    options << [ "Everyone", "everyone" ] if manage_employment
    options << [ "My Direct Employees", "my_direct_employees" ] if current_company_teammate&.has_direct_reports?
    options << [ "My Employees (full hierarchy)", "my_employees_full_hierarchy" ] if current_company_teammate && hierarchy_count_excluding_self.positive?
    options << [ "Just Me", "just_me" ]
    options.concat(visible_managers_for_goals_health(company))
    options
  end

  def manager_filter_viewable?(manager_id)
    manager_viewable?(manager_id)
  end

  private

  def row_for(teammate, goals, records, attachment_facts)
    category = GoalsHealthEngagementHealthSupport.category_rollup(records)
    eh_status = GoalsHealthEngagementHealthSupport.category_status(records)
    overall_status = GoalsHealthEngagementHealthSupport.spotlight_symbol(eh_status)
    items = GoalsHealthEngagementHealthSupport.items_for(records)
    active_goals = goals.select { |goal| goal.completed_at.nil? && goal.started_at.present? }

    {
      teammate: teammate,
      person: teammate.person,
      manager: Goals::HealthManagerPerson.for(teammate),
      manager_teammate: Goals::HealthManagerPerson.manager_teammate_for(teammate),
      status: overall_status,
      eh_status: eh_status,
      goals: goals,
      engagement_health_records: records,
      empty_reason: category&.inputs&.dig("empty_reason"),
      status_lines: status_lines_from_items(items, goals),
      attachments: GoalsHealthAttachmentLookup.entry_for_active_goals(active_goals, attachment_facts)
    }
  end

  def status_lines_from_items(items, goals)
    base = EngagementHealth::STATUSES.index_with { { active: 0, completed: 0, draft: 0 } }
    items.each do |item|
      status = item.status
      next unless base.key?(status)

      if item.inputs["goal_state"].to_s == "completed"
        base[status][:completed] += 1
      else
        base[status][:active] += 1
      end
    end

    draft_count = Array(goals).count { |goal| goal.completed_at.nil? && goal.started_at.nil? }
    base[EngagementHealth::NEEDS_ATTENTION][:draft] = draft_count
    base
  end

  def spotlight_stats(rows)
    total_employees = rows.count
    healthy_count = rows.count { |row| row[:status] == :healthy }
    warning_count = rows.count { |row| row[:status] == :ok }
    needs_attention_count = rows.count { |row| row[:status] == :concerning }
    concerning_pct = total_employees.positive? ? ((needs_attention_count.to_f / total_employees) * 100).round(1) : 0.0

    {
      total_employees: total_employees,
      healthy_count: healthy_count,
      warning_count: warning_count,
      needs_attention_count: needs_attention_count,
      ok_count: warning_count,
      concerning_count: needs_attention_count,
      concerning_pct: concerning_pct
    }
  end

  def hierarchy_count_excluding_self
    return 0 unless current_company_teammate && organization

    ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, organization).pluck(:id)
    ids.size > 1 ? ids.size - 1 : 0
  end

  def filtered_teammates_for_mid(manager_id)
    base_scope = CompanyTeammate.for_organization_hierarchy(organization)
      .where.not(first_employed_at: nil)
      .where(last_terminated_at: nil)
      .includes(:person, :organization, employment_tenures: { manager_teammate: :person })
      .joins(:person)
      .order("people.last_name ASC, people.first_name ASC")

    case manager_id.to_s
    when "everyone"
      return base_scope if manage_employment

      viewing_teammate = base_scope.find_by(person: current_person)
      if viewing_teammate
        hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(viewing_teammate, organization).pluck(:id)
        base_scope.where(id: hierarchy_ids)
      else
        base_scope.none
      end
    when "my_direct_employees"
      return base_scope.none unless current_company_teammate&.has_direct_reports?

      direct_report_ids = EmploymentTenure
        .where(company: organization, manager_teammate: current_company_teammate, ended_at: nil)
        .pluck(:teammate_id)
      base_scope.where(id: direct_report_ids)
    when "my_employees_full_hierarchy"
      return base_scope.none unless current_company_teammate

      hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, organization).pluck(:id)
      base_scope.where(id: hierarchy_ids)
    when "just_me"
      return base_scope.none unless current_company_teammate

      base_scope.where(id: current_company_teammate.id)
    else
      if manager_id.to_s =~ /\ACompanyTeammate_(\d+)\z/
        mgr_id = Regexp.last_match(1).to_i
        return base_scope.none unless manager_viewable?(mgr_id)

        direct_report_ids = EmploymentTenure
          .where(company: organization, manager_teammate_id: mgr_id, ended_at: nil)
          .pluck(:teammate_id)
        base_scope.where(id: direct_report_ids)
      else
        filtered_teammates_for_mid(default_manager_filter_value)
      end
    end
  end

  def manager_viewable?(manager_id)
    return true if manage_employment
    return false unless current_company_teammate

    hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, organization).pluck(:id)
    hierarchy_ids.include?(manager_id)
  end

  def visible_managers_for_goals_health(company)
    if manage_employment
      manager_teammate_ids = EmploymentTenure
        .where(company: company, ended_at: nil)
        .where.not(manager_teammate_id: nil)
        .distinct
        .pluck(:manager_teammate_id)
    else
      return [] unless current_company_teammate

      hierarchy_ids = CompanyTeammate.self_and_reporting_hierarchy(current_company_teammate, organization).pluck(:id)
      manager_teammate_ids = EmploymentTenure
        .where(company: company, ended_at: nil, manager_teammate_id: hierarchy_ids)
        .where.not(manager_teammate_id: nil)
        .distinct
        .pluck(:manager_teammate_id)
    end

    teammates = CompanyTeammate.where(id: manager_teammate_ids).joins(:person).order("people.last_name ASC", "people.first_name ASC")
    teammates.map { |tm| [ "Manager: #{tm.person&.display_name}", "CompanyTeammate_#{tm.id}" ] }.reject { |pair| pair[0].blank? }
  end
end
