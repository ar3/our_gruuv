# frozen_string_literal: true

class Organizations::GoalsBulkEditController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_goal, only: :update
  after_action :verify_authorized

  def show
    authorize Goal.new, :bulk_edit?
    resolve_owner_filter!
    load_sheet_goals!
    @owner_options = sheet_owner_options
    @default_owner_value = sheet_owner_value
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
      render json: { ok: true, saved_at: result.saved_at, started: result.goal.started_at.present? }
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
    raw = params[:owner_id].presence
    if raw.blank? && current_company_teammate
      @owner_type = "CompanyTeammate"
      @owner_id = current_company_teammate.id
      return
    end

    if raw.present? && raw.match?(/\A(CompanyTeammate|Team|Department|Company|Organization)_\d+\z/)
      type, id = raw.split("_", 2)
      type = "Organization" if type == "Company"
      @owner_type = type
      @owner_id = id
    elsif current_company_teammate
      @owner_type = "CompanyTeammate"
      @owner_id = current_company_teammate.id
    else
      @owner_type = nil
      @owner_id = nil
    end
  end

  def sheet_owner_value
    return nil if @owner_type.blank? || @owner_id.blank?

    type = @owner_type == "Organization" ? "Company" : @owner_type
    "#{type}_#{@owner_id}"
  end

  def sheet_owner_value_from_goal(goal)
    type = goal.owner_type == "Organization" ? "Company" : goal.owner_type
    "#{type}_#{goal.owner_id}"
  end

  def load_sheet_goals!
    scope = policy_scope(Goal).where(deleted_at: nil, completed_at: nil)
    if @owner_type.present? && @owner_id.present?
      scope = scope.where(owner_type: @owner_type, owner_id: @owner_id)
    else
      scope = scope.none
    end
    @goals = scope.includes(:goal_check_ins, :owner, creator: :person).order(:created_at).to_a
  end

  def sheet_owner_options
    sheet_owner_options_grouped.flat_map { |_group, options| options }
  end

  def sheet_owner_options_grouped
    company = @organization.root_company || @organization
    groups = []
    teammate = current_company_teammate

    teammate_opts = []
    if teammate&.person
      label = teammate.person.casual_name.presence || teammate.person.display_name
      teammate_opts << [label, "CompanyTeammate_#{teammate.id}"] if label.present?
    end
    groups << ["Teammates", teammate_opts] if teammate_opts.any?

    company_opts = []
    if company.display_name.present? && company.id.present?
      company_opts << [company.display_name, "Company_#{company.id}"]
    end
    groups << ["Company", company_opts] if company_opts.any?

    dept_opts = Department.for_company(company).active.ordered.filter_map do |dept|
      next if dept.display_name.blank?

      [dept.display_name, "Department_#{dept.id}"]
    end
    groups << ["Departments", dept_opts] if dept_opts.any?

    team_opts = Team.for_company(company).active.ordered.filter_map do |team|
      next if team.display_name.blank?

      [team.display_name, "Team_#{team.id}"]
    end
    groups << ["Teams", team_opts] if team_opts.any?

    groups
  end

  def sheet_owner_filter_label
    value = sheet_owner_value
    sheet_owner_options_grouped.flat_map { |_group, options| options }.find { |_label, v| v == value }&.first || "Select owner"
  end
  helper_method :sheet_owner_options, :sheet_owner_options_grouped, :sheet_owner_value, :sheet_owner_filter_label
end
