# frozen_string_literal: true

class Organizations::GoalsBulkEditController < Organizations::OrganizationNamespaceBaseController
  SPECIAL_OWNER_FILTERS = %w[
    my_relevant_goals
    all_my_teams
    my_department
    my_employees
    my_employees_hierarchy
    everyone_in_company
    created_by_me
  ].freeze

  before_action :authenticate_person!
  before_action :set_goal, only: :update
  after_action :verify_authorized

  def show
    authorize Goal.new, :bulk_edit?
    resolve_owner_filter!
    @selected_statuses = sheet_status_filters
    @current_filters = { status: @selected_statuses }
    load_sheet_goals!
    @owner_options = sheet_assignable_owner_options_grouped
    @default_owner_value = sheet_default_assignable_owner_value
    @hierarchy = Goals::HierarchyWithCheckInsQuery.new(
      goals: @goals,
      current_person: current_person,
      organization: @organization
    ).call
  end

  def create
    authorize Goal.new, :bulk_edit?
    unless current_company_teammate
      return respond_create_error(["You must be a company teammate to create goals"])
    end

    parent_goal = find_parent_goal(params[:parent_id])
    if params[:parent_id].present? && parent_goal.nil?
      return respond_create_error(["Parent goal not found or not editable"])
    end

    result = Goals::BulkEditCreate.call(
      organization: @organization,
      current_person: current_person,
      current_teammate: current_company_teammate,
      attrs: create_params,
      parent_goal: parent_goal
    )

    if result.ok?
      redirect_to organization_goals_bulk_edit_path(@organization, owner_id: sheet_owner_value_from_goal(result.goal)),
                  notice: parent_goal ? "Child goal added." : "Goal added."
    else
      respond_create_error(result.errors)
    end
  end

  def update
    authorize @goal, :update?

    unless current_company_teammate
      return render json: { ok: false, errors: "You must be a company teammate" }, status: :unprocessable_entity
    end

    result = Goals::BulkEditUpdate.call(
      goal: @goal,
      current_person: current_person,
      current_teammate: current_company_teammate,
      attrs: update_params
    )

    if result.ok?
      goal = result.goal
      render json: {
        ok: true,
        saved_at: result.saved_at,
        started: goal.started_at.present?,
        completed: goal.completed_at.present?,
        sheet_row: {
          row_classes: helpers.goals_bulk_edit_row_classes(goal),
          popover_title: helpers.goals_bulk_edit_border_popover_title(goal),
          popover_content: helpers.goals_bulk_edit_border_popover_content(goal)
        }
      }
    else
      render json: { ok: false, errors: result.errors.join(", ") }, status: :unprocessable_entity
    end
  end

  private

  def set_goal
    @goal = policy_scope(Goal).find(params[:id])
  end

  def create_params
    params.require(:goal).permit(
      :title, :goal_type, :privacy_level, :description, :most_likely_target_date, :owner_id,
      :confidence_percentage, :confidence_reason
    )
  end

  def update_params
    params.require(:goal).permit(
      :title, :goal_type, :privacy_level, :description, :most_likely_target_date, :owner_id,
      :confidence_percentage, :confidence_reason
    )
  end

  def respond_create_error(errors)
    redirect_to organization_goals_bulk_edit_path(@organization, owner_id: params[:owner_id].presence || sheet_owner_value),
                alert: Array(errors).join(", ")
  end

  def find_parent_goal(parent_id)
    return nil if parent_id.blank?

    goal = policy_scope(Goal).find_by(id: parent_id)
    return nil unless goal
    return nil unless policy(goal).update?

    goal
  end

  def resolve_owner_filter!
    raw = params[:owner_id].presence || "my_relevant_goals"
    @special_owner_filter = nil
    @owner_type = nil
    @owner_id = nil

    if SPECIAL_OWNER_FILTERS.include?(raw)
      @special_owner_filter = raw
      return
    end

    if raw.match?(/\A(CompanyTeammate|Team|Department|Company|Organization)_\d+\z/)
      type, id = raw.split("_", 2)
      type = "Organization" if type == "Company"
      @owner_type = type
      @owner_id = id
      return
    end

    @special_owner_filter = "my_relevant_goals"
  end

  def sheet_owner_value
    return @special_owner_filter if @special_owner_filter.present?
    return nil if @owner_type.blank? || @owner_id.blank?

    type = @owner_type == "Organization" ? "Company" : @owner_type
    "#{type}_#{@owner_id}"
  end

  def sheet_default_assignable_owner_value
    if @owner_type.present? && @owner_id.present?
      type = @owner_type == "Organization" ? "Company" : @owner_type
      return "#{type}_#{@owner_id}"
    end

    return "CompanyTeammate_#{current_company_teammate.id}" if current_company_teammate

    nil
  end

  def sheet_owner_value_from_goal(goal)
    type = goal.owner_type == "Organization" ? "Company" : goal.owner_type
    "#{type}_#{goal.owner_id}"
  end

  def load_sheet_goals!
    # Incomplete only on load. Completing via autosave keeps the row in the DOM (black bar);
    # a full reload hides it again until the user includes Completed in status filters.
    scope = policy_scope(Goal).incomplete_unarchived
    teammate = current_company_teammate
    company = @organization.root_company || @organization

    scope = case @special_owner_filter
            when "my_relevant_goals"
              scope.merge(my_relevant_goals_condition(teammate))
            when "everyone_in_company"
              scope.where(privacy_level: "everyone_in_company")
            when "created_by_me"
              teammate ? scope.where(creator: teammate) : scope.none
            when "all_my_teams"
              team_ids = teams_for_teammate(teammate, company).map(&:id)
              team_ids.any? ? scope.where(owner_type: "Team", owner_id: team_ids) : scope.none
            when "my_department"
              department = teammate&.active_employment_tenure&.position&.title&.department
              if department
                Goals::RelatedToDepartmentQuery.call(relation: scope, department: department)
              else
                scope.where(privacy_level: "everyone_in_company")
              end
            when "my_employees", "my_employees_hierarchy"
              owner_ids = if @special_owner_filter == "my_employees_hierarchy"
                            Goals::EmployeeOwnedGoalsQuery.hierarchy_report_ids(
                              manager: teammate,
                              organization: @organization
                            )
                          else
                            Goals::EmployeeOwnedGoalsQuery.direct_report_ids(
                              manager: teammate,
                              organization: @organization
                            )
                          end
              # Keep drafts on the sheet (index employee filter uses .active only).
              if owner_ids.any?
                scope.where(owner_type: "CompanyTeammate", owner_id: owner_ids)
              else
                scope.none
              end
            else
              if @owner_type == "Department" && @owner_id.present?
                department = Department.find_by(id: @owner_id)
                Goals::RelatedToDepartmentQuery.call(relation: scope, department: department)
              elsif @owner_type.present? && @owner_id.present?
                scope.where(owner_type: @owner_type, owner_id: @owner_id)
              else
                scope.none
              end
            end

    pre_status = scope
    matching = apply_sheet_status_filter(pre_status, @selected_statuses || sheet_status_filters)
    expanded_ids = Goals::IncludeAncestorGoals.expanded_ids(matching: matching, candidates: pre_status)
    scope = pre_status.where(id: expanded_ids)

    @goals = scope.includes(:goal_check_ins, :owner, creator: :person).order(:created_at).to_a
  end

  def sheet_status_filters
    explicit = Array(params[:status]).compact.select { |value| %w[draft active completed archived].include?(value) }.uniq
    return explicit if explicit.present?

    %w[draft active]
  end

  def apply_sheet_status_filter(goals, statuses)
    return goals if statuses.blank?
    return goals if statuses.sort == %w[active draft]

    status_scope = nil
    statuses.each do |status|
      scope = case status
              when "draft" then goals.draft
              when "active" then goals.active
              when "completed" then goals.where.not(completed_at: nil)
              when "archived" then goals.where.not(deleted_at: nil)
              end
      next unless scope

      status_scope = status_scope ? status_scope.or(scope) : scope
    end
    status_scope || goals.none
  end

  def sheet_filter_query_params
    params_hash = { owner_id: sheet_owner_value }.compact
    statuses = @selected_statuses || sheet_status_filters
    unless statuses.sort == %w[active draft]
      params_hash[:status] = statuses
    end
    params_hash
  end

  def my_relevant_goals_condition(teammate)
    company_wide = Goal.where(privacy_level: "everyone_in_company")
    return company_wide unless teammate

    company_wide.or(Goal.where(owner_type: "CompanyTeammate", owner_id: teammate.id))
  end

  def teams_for_teammate(teammate, company)
    return Team.none unless teammate && company

    Team.active.where(company: company)
        .joins(:team_members)
        .where(team_members: { company_teammate_id: teammate.id })
        .ordered
        .distinct
  end

  def sheet_owner_options
    sheet_owner_options_grouped.flat_map { |_group, options| options }
  end

  def sheet_owner_options_grouped
    company = @organization.root_company || @organization
    groups = []
    teammate = current_company_teammate

    filter_opts = [
      ["My relevant goals", "my_relevant_goals"],
      ["All my teams", "all_my_teams"],
      ["My department goals", "my_department"],
      ["My employees' goals", "my_employees"],
      ["My employees' goals (full hierarchy)", "my_employees_hierarchy"]
    ]
    if company.display_name.present?
      filter_opts << ["All goals visible to everyone at #{company.display_name}", "everyone_in_company"]
    end
    filter_opts << ["All goals created by me", "created_by_me"]
    groups << ["Filter", filter_opts]

    teammate_opts = []
    if teammate&.person
      label = teammate.person.casual_name.presence || teammate.person.display_name
      teammate_opts << [label, "CompanyTeammate_#{teammate.id}"] if label.present?
    end
    managed_teammates_in_hierarchy(company, teammate).each do |managed|
      next unless managed.person && managed.id.present?

      label = managed.person.casual_name.presence || managed.person.display_name
      next if label.blank?

      teammate_opts << [label, "CompanyTeammate_#{managed.id}"]
    end
    groups << ["Teammates", sort_sheet_owner_options(teammate_opts)] if teammate_opts.any?

    company_opts = []
    if company.display_name.present? && company.id.present?
      company_opts << [company.display_name, "Company_#{company.id}"]
    end
    groups << ["Company", sort_sheet_owner_options(company_opts)] if company_opts.any?

    dept_opts = Department.for_company(company).active.ordered.filter_map do |dept|
      next if dept.display_name.blank?

      [dept.display_name, "Department_#{dept.id}"]
    end
    groups << ["Departments", sort_sheet_owner_options(dept_opts)] if dept_opts.any?

    team_opts = Team.for_company(company).active.ordered.filter_map do |team|
      next if team.display_name.blank?

      [team.display_name, "Team_#{team.id}"]
    end
    groups << ["Teams", sort_sheet_owner_options(team_opts)] if team_opts.any?

    groups
  end

  def sheet_assignable_owner_options_grouped
    sheet_owner_options_grouped.reject { |group_label, _options| group_label == "Filter" }
  end

  def sort_sheet_owner_options(options)
    options.sort_by { |label, _value| label.to_s.downcase }
  end

  def managed_teammates_in_hierarchy(company, current_teammate)
    return [] unless current_teammate

    CompanyTeammate
      .self_and_reporting_hierarchy(current_teammate, company)
      .includes(:person)
      .where.not(id: current_teammate.id)
      .to_a
      .sort_by { |tm| [tm.person&.last_name.to_s.downcase, tm.person&.first_name.to_s.downcase] }
  end

  def sheet_owner_filter_label
    value = sheet_owner_value
    sheet_owner_options_grouped.flat_map { |_group, options| options }.find { |_label, v| v == value }&.first || "Select owner"
  end
  helper_method :sheet_owner_options,
                :sheet_owner_options_grouped,
                :sheet_assignable_owner_options_grouped,
                :sheet_owner_value,
                :sheet_default_assignable_owner_value,
                :sheet_owner_filter_label,
                :sheet_filter_query_params
end
