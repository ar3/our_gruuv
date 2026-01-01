class Organizations::CompanyTeammates::GoalCheckInsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_teammate
  before_action :load_goals_for_check_in

  def show
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    
    # Set return URL and text from params with defaults
    @return_url = params[:return_url] || organization_company_teammate_check_ins_path(organization, @teammate)
    @return_text = params[:return_text] || "Back to Check-ins"
    
    render layout: 'overlay'
  end

  def update
    authorize @teammate, :view_check_ins?, policy_class: CompanyTeammatePolicy
    
    week_start = Date.current.beginning_of_week(:monday)
    result = Goals::BulkUpdateCheckInsService.call(
      organization: organization,
      current_person: current_person,
      goal_check_ins_params: params[:goal_check_ins] || {},
      week_start: week_start
    )
    
    # Get return URL and text from params
    return_url = params[:return_url] || organization_company_teammate_check_ins_path(organization, @teammate)
    return_text = params[:return_text] || "Back to Check-ins"
    
    if result.ok?
      if result.value[:failure_count] > 0
        redirect_to return_url,
                    alert: "Some check-ins failed to save. #{result.value[:success_count]} saved, #{result.value[:failure_count]} failed."
      else
        redirect_to return_url,
                    notice: "Successfully saved #{result.value[:success_count]} check-in(s)."
      end
    else
      redirect_to return_url,
                  alert: "Failed to save check-ins: #{result.error}"
    end
  end

  private

  def set_teammate
    @teammate = organization.teammates.find(params[:company_teammate_id])
  end

  def load_goals_for_check_in
    return unless @teammate
    
    # Load all goals where the teammate is the owner, has a start date, and does not have a completed date
    base_goals = Goal.where(
      company: organization,
      owner_type: 'CompanyTeammate',
      owner_id: @teammate.id,
      deleted_at: nil,
      completed_at: nil
    ).where.not(started_at: nil).includes(:goal_check_ins, :recent_check_ins)
    
    @goals = base_goals.order(:most_likely_target_date)
    @current_week_start = Date.current.beginning_of_week(:monday)
    
    goal_ids = @goals.pluck(:id)
    
    # Load current week check-ins
    @goal_check_ins = GoalCheckIn
      .where(goal_id: goal_ids, check_in_week_start: @current_week_start)
      .includes(:confidence_reporter)
      .index_by(&:goal_id)
    
    # Preload recent check-ins for all goals (last 3 weeks)
    recent_check_ins = GoalCheckIn
      .where(goal_id: goal_ids)
      .where('check_in_week_start >= ?', @current_week_start - 3.weeks)
      .includes(:confidence_reporter)
      .order(check_in_week_start: :desc)
      .group_by(&:goal_id)
    
    @recent_check_ins_by_goal = recent_check_ins.transform_values { |check_ins| check_ins.first(3) }
  end
end

