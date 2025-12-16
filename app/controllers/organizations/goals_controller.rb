class Organizations::GoalsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_goal, only: [:show, :edit, :update, :destroy, :start, :check_in, :set_timeframe, :done, :complete, :undelete]
  
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index
  
  def index
    authorize company, :view_goals?
    # Parse owner_id if it's in format "Type_ID" (e.g., "Teammate_123")
    if params[:owner_id].present? && params[:owner_id].include?('_') && params[:owner_type].blank?
      owner_type, owner_id = params[:owner_id].split('_', 2)
      params[:owner_type] = owner_type
      params[:owner_id] = owner_id
    end
    
    # Get current teammate for this organization
    current_teammate = current_person.teammates.find_by(organization: @organization)
    
    # Default to logged in user if no owner is selected
    unless params[:owner_type].present? && params[:owner_id].present?
      if current_teammate
        params[:owner_type] = 'Teammate'
        params[:owner_id] = current_teammate.id.to_s
      else
        @goals = policy_scope(Goal.none)
        @view_style = params[:view] || 'hierarchical-indented'
        @view_style = 'hierarchical-indented' unless %w[table cards list network tree nested timeline check-in hierarchical-indented].include?(@view_style)
        @goal_count = 0
        @show_performance_warning = false
        @current_filters = {
          timeframe: params[:timeframe],
          goal_type: params[:goal_type],
          status: params[:status],
          sort: params[:sort],
          direction: params[:direction],
          view: @view_style,
          spotlight: params[:spotlight],
          owner_type: params[:owner_type],
          owner_id: params[:owner_id],
          show_deleted: params[:show_deleted],
          show_completed: params[:show_completed]
        }
        return
      end
    end
    
    # Start with goals visible to the teammate (filtered by company_id via policy scope)
    @goals = policy_scope(Goal)
    @goals = Goals::FilterQuery.new(@goals).call(
      show_deleted: params[:show_deleted] == '1',
      show_completed: params[:show_completed] == '1'
    )
    
    # Filter by owner
    @goals = @goals.where(owner_type: params[:owner_type], owner_id: params[:owner_id])
    
    # Set default spotlight
    spotlight_param = params[:spotlight]
    if spotlight_param.blank? || spotlight_param == 'none'
      spotlight_param = 'goals_overview'
    end
    
    # Calculate spotlight stats for goals_overview (before other filters)
    if spotlight_param == 'goals_overview'
      all_goals_for_owner = policy_scope(Goal).where(owner_type: params[:owner_type], owner_id: params[:owner_id])
      all_goals_for_owner = Goals::FilterQuery.new(all_goals_for_owner).call(
        show_deleted: params[:show_deleted] == '1',
        show_completed: params[:show_completed] == '1'
      )
      @spotlight_stats = helpers.calculate_goals_overview_stats(all_goals_for_owner)
    end
    
    # Apply filters
    @goals = apply_timeframe_filter(@goals, params[:timeframe])
    @goals = apply_goal_type_filter(@goals, params[:goal_type])
    @goals = apply_status_filter(@goals, params[:status])
    @goals = apply_spotlight_filter(@goals, spotlight_param)
    
    # Apply sorting
    @goals = apply_sorting(@goals, params[:sort], params[:direction])
    
    # Set view style
    @view_style = params[:view] || 'hierarchical-indented'
    @view_style = 'hierarchical-indented' unless %w[table cards list network tree nested timeline check-in hierarchical-indented].include?(@view_style)
    
    # For check-in view, filter to eligible goals and load check-ins
    if @view_style == 'check-in'
      @goals = @goals.check_in_eligible.includes(:goal_check_ins, :recent_check_ins)
      @current_week_start = Date.current.beginning_of_week(:monday)
      goal_ids = @goals.pluck(:id)
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
    
    # Performance check for visualizations
    @goal_count = @goals.count
    @show_performance_warning = @goal_count > 100 && %w[network tree nested timeline].include?(@view_style)
    
    # Store filter/sort params for view
    @current_filters = {
      timeframe: params[:timeframe],
      goal_type: params[:goal_type],
      status: params[:status],
      sort: params[:sort],
      direction: params[:direction],
      view: @view_style,
      spotlight: spotlight_param,
      owner_type: params[:owner_type],
      owner_id: params[:owner_id],
      show_deleted: params[:show_deleted],
      show_completed: params[:show_completed]
    }
    
    # Set current spotlight for view
    @current_spotlight = spotlight_param
  end
  
  def show
    authorize @goal
    
    # Load all check-ins chronologically (oldest first) for display
    @all_check_ins = @goal.goal_check_ins
      .includes(:confidence_reporter)
      .order(check_in_week_start: :asc)
    
    # Load check-in data for started goals
    if @goal.started_at.present?
      @current_week_start = Date.current.beginning_of_week(:monday)
      @current_check_in = @goal.goal_check_ins
        .for_week(@current_week_start)
        .includes(:confidence_reporter)
        .first
      
      # Load last check-in (most recent before current week)
      @last_check_in = @goal.goal_check_ins
        .where('check_in_week_start < ?', @current_week_start)
        .includes(:confidence_reporter)
        .recent
        .first
    end
    
    # Preload check-ins for linked goals (for displaying check-in info and status icons)
    # Load linked goals explicitly to include completed/deleted goals
    linked_goal_ids = (@goal.outgoing_links.pluck(:child_id) + @goal.incoming_links.pluck(:parent_id)).uniq
    if linked_goal_ids.any?
      # Load all linked goals including completed and deleted
      @linked_goals = Goal.where(id: linked_goal_ids).index_by(&:id)
      
      # Preload check-ins for linked goals
      @goal.outgoing_links.includes(child: :goal_check_ins).load
      @goal.incoming_links.includes(parent: :goal_check_ins).load
      
      # Reload associations to use the explicitly loaded goals
      @goal.outgoing_links.each do |link|
        link.association(:child).target = @linked_goals[link.child_id] if @linked_goals[link.child_id]
      end
      @goal.incoming_links.each do |link|
        link.association(:parent).target = @linked_goals[link.parent_id] if @linked_goals[link.parent_id]
      end
      
      @linked_goal_check_ins = GoalCheckIn
        .where(goal_id: linked_goal_ids)
        .includes(:confidence_reporter, :goal)
        .recent
        .group_by(&:goal_id)
        .transform_values { |check_ins| check_ins.first }
    else
      @linked_goals = {}
      @linked_goal_check_ins = {}
    end
  end
  
  def new
    company = @organization.root_company || @organization
    @goal = Goal.new(company: company)
    authorize @goal
    
    @form = GoalForm.new(@goal)
    @form.current_person = current_person
    # Find teammate in the company or any descendant organization
    company_descendant_ids = company.self_and_descendants.pluck(:id)
    @form.current_teammate = current_person.teammates.find_by(organization_id: company_descendant_ids)
    # Set defaults
    @form.goal_type = 'inspirational_objective' # Default to objective
    @form.privacy_level = 'everyone_in_company'
    # Default owner to current teammate if they have a teammate record
    # Use unified format for the select dropdown
    if @form.current_teammate
      @form.owner_id = "Teammate_#{@form.current_teammate.id}"
    end
    authorize @goal
  end
  
  def create
    authorize Goal.new
    
    @goal = Goal.new
    @form = GoalForm.new(@goal)
    @form.current_person = current_person
    @form.current_teammate = current_person.teammates.find_by(organization: @organization)
    
    goal_params = params[:goal] || {}
    
    if @form.validate(goal_params) && @form.save
      redirect_to organization_goal_path(@organization, @goal), 
                  notice: 'Goal was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @form = GoalForm.new(@goal)
    @form.current_person = current_person
    @form.current_teammate = current_person.teammates.find_by(organization: @organization)
    authorize @goal
  end
  
  def update
    authorize @goal
    
    @form = GoalForm.new(@goal)
    @form.current_person = current_person
    @form.current_teammate = current_person.teammates.find_by(organization: @organization)
    
    goal_params = params[:goal] || {}
    
    if @form.validate(goal_params) && @form.save
      redirect_to organization_goal_path(@organization, @goal), 
                  notice: 'Goal was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    authorize @goal
    
    @goal.soft_delete!
    redirect_to organization_goals_path(@organization), 
                notice: 'Goal was successfully deleted.'
  end
  
  def undelete
    authorize @goal, :update?
    
    @goal.update!(deleted_at: nil)
    redirect_to organization_goal_path(@organization, @goal),
                notice: 'Goal was successfully restored.'
  end
  
  def start
    authorize @goal, :update?
    
    if @goal.started_at.present?
      redirect_path = params[:parent_goal_id].present? ? 
        organization_goal_path(@organization, params[:parent_goal_id]) : 
        organization_goal_path(@organization, @goal)
      redirect_to redirect_path,
                  alert: 'Goal has already been started.'
      return
    end
    
    if @goal.update(started_at: Time.current)
      redirect_path = params[:parent_goal_id].present? ? 
        organization_goal_path(@organization, params[:parent_goal_id]) : 
        organization_goal_path(@organization, @goal)
      redirect_to redirect_path,
                  notice: 'Goal started successfully.'
    else
      redirect_path = params[:parent_goal_id].present? ? 
        organization_goal_path(@organization, params[:parent_goal_id]) : 
        organization_goal_path(@organization, @goal)
      redirect_to redirect_path,
                  alert: 'Failed to start goal.'
    end
  end
  
  def check_in
    authorize @goal, :show?
    
    # Check authorization for check-in
    check_in_record = GoalCheckIn.new(goal: @goal)
    authorize check_in_record, :create?
    
    week_start = Date.current.beginning_of_week(:monday)
    confidence_percentage = params[:confidence_percentage]&.to_i
    confidence_reason = params[:confidence_reason]&.strip
    
    # Set PaperTrail whodunnit for version tracking
    PaperTrail.request.whodunnit = current_person.id.to_s
    
    # Find or initialize check-in for current week
    check_in = GoalCheckIn.find_or_initialize_by(
      goal: @goal,
      check_in_week_start: week_start
    )
    
    check_in.assign_attributes(
      confidence_percentage: confidence_percentage,
      confidence_reason: confidence_reason,
      confidence_reporter: current_person
    )
    
    if check_in.save
      # Auto-complete goal if confidence is 0% or 100%
      if (confidence_percentage == 0 || confidence_percentage == 100) && @goal.completed_at.nil?
        @goal.update(completed_at: Time.current)
      end
      
      redirect_to organization_goal_path(@organization, @goal),
                  notice: 'Check-in saved successfully.'
    else
      redirect_to organization_goal_path(@organization, @goal),
                  alert: "Failed to save check-in: #{check_in.errors.full_messages.join(', ')}"
    end
  end
  
  def set_timeframe
    authorize @goal, :update?
    
    timeframe = params[:timeframe]
    
    unless %w[near_term medium_term long_term vision].include?(timeframe)
      redirect_to organization_goal_path(@organization, @goal),
                  alert: 'Invalid timeframe selected.'
      return
    end
    
    @form = GoalForm.new(@goal)
    @form.current_person = current_person
    @form.current_teammate = current_person.teammates.find_by(organization: @organization)
    
    goal_params = {}
    
    if timeframe == 'vision'
      # Convert to vision goal - only change goal_type, don't set target dates
      goal_params = {
        goal_type: 'inspirational_objective',
        title: @goal.title,
        description: @goal.description,
        privacy_level: @goal.privacy_level,
        owner_type: @goal.owner_type,
        owner_id: @goal.owner_id
      }
    else
      # Set target dates based on timeframe
      today = Date.current
      case timeframe
      when 'near_term'
        most_likely = today + 90.days
        earliest = today + 30.days
        latest = today + 120.days
      when 'medium_term'
        most_likely = today + 270.days
        earliest = today + 180.days
        latest = today + 360.days
      when 'long_term'
        most_likely = today + 3.years
        earliest = today + 2.years
        latest = today + 4.years
      end
      
      goal_params = {
        title: @goal.title,
        description: @goal.description,
        goal_type: @goal.goal_type,
        earliest_target_date: earliest,
        most_likely_target_date: most_likely,
        latest_target_date: latest,
        privacy_level: @goal.privacy_level,
        owner_type: @goal.owner_type,
        owner_id: @goal.owner_id
      }
    end
    
    if @form.validate(goal_params) && @form.save
      notice_message = case timeframe
      when 'vision'
        'Goal converted to vision successfully.'
      when 'near_term'
        'Goal set to near-term timeframe successfully.'
      when 'medium_term'
        'Goal set to medium-term timeframe successfully.'
      when 'long_term'
        'Goal set to long-term timeframe successfully.'
      end
      
      redirect_to organization_goal_path(@organization, @goal),
                  notice: notice_message
    else
      redirect_to organization_goal_path(@organization, @goal),
                  alert: "Failed to set timeframe: #{@form.errors.full_messages.join(', ')}"
    end
  end
  
  def customize_view
    authorize @organization, :show?
    
    # Parse owner_id if it's in format "Type_ID" (e.g., "Teammate_123")
    if params[:owner_id].present? && params[:owner_id].include?('_') && params[:owner_type].blank?
      owner_type, owner_id = params[:owner_id].split('_', 2)
      params[:owner_type] = owner_type
      params[:owner_id] = owner_id
    end
    
    # Default to logged in user if no owner is selected
    unless params[:owner_type].present? && params[:owner_id].present?
      current_teammate = current_person.teammates.find_by(organization: @organization)
      if current_teammate
        params[:owner_type] = 'Teammate'
        params[:owner_id] = current_teammate.id.to_s
      end
    end
    
    # Load current state from params
    @current_filters = {
      timeframe: params[:timeframe],
      goal_type: params[:goal_type],
      status: params[:status],
      sort: params[:sort] || 'most_likely_target_date',
      direction: params[:direction] || 'asc',
      view: params[:view] || 'hierarchical-indented',
      spotlight: params[:spotlight] || 'goals_overview',
      owner_type: params[:owner_type],
      owner_id: params[:owner_id],
      show_deleted: params[:show_deleted],
      show_completed: params[:show_completed]
    }
    
    @current_sort = @current_filters[:sort]
    @current_view = @current_filters[:view]
    @current_spotlight = @current_filters[:spotlight]
    
    # Preserve current params for return URL
    return_params = params.except(:controller, :action, :page).permit!.to_h
    @return_url = organization_goals_path(@organization, return_params)
    @return_text = "Back to Goals"
    
    render layout: 'overlay'
  end
  
  def update_view
    authorize @organization, :show?
    
    # Build redirect URL with all view customization params
    redirect_params = params.except(:controller, :action, :authenticity_token, :_method, :commit).permit!.to_h.compact
    
    redirect_to organization_goals_path(@organization, redirect_params), notice: 'View updated successfully.'
  end
  
  def bulk_update_check_ins
    authorize @organization, :show?
    
    week_start = Date.current.beginning_of_week(:monday)
    result = Goals::BulkUpdateCheckInsService.call(
      organization: @organization,
      current_person: current_person,
      goal_check_ins_params: params[:goal_check_ins] || {},
      week_start: week_start
    )
    
    if result.ok?
      if result.value[:failure_count] > 0
        redirect_to organization_goals_path(@organization, params.except(:controller, :action, :goal_check_ins, :authenticity_token, :commit).permit!.to_h),
                    alert: "Some check-ins failed to save. #{result.value[:success_count]} saved, #{result.value[:failure_count]} failed."
      else
        redirect_to organization_goals_path(@organization, params.except(:controller, :action, :goal_check_ins, :authenticity_token, :commit).permit!.to_h),
                    notice: "Successfully saved #{result.value[:success_count]} check-in(s)."
      end
    else
      redirect_to organization_goals_path(@organization, params.except(:controller, :action, :goal_check_ins, :authenticity_token, :commit).permit!.to_h),
                  alert: "Failed to save check-ins: #{result.error}"
    end
  end
  
  def done
    authorize @goal, :update?
    
    @return_url = params[:return_url] || organization_goal_path(@organization, @goal)
    @return_text = params[:return_text] || 'Goal'
    
    @check_ins = @goal.goal_check_ins
      .includes(:confidence_reporter)
      .order(check_in_week_start: :desc)
    
    @current_week_start = Date.current.beginning_of_week(:monday)
  end
  
  def complete
    authorize @goal, :update?
    
    completed_outcome = params[:completed_outcome]
    learnings = params[:learnings]&.strip
    
    if learnings.blank?
      @check_ins = @goal.goal_check_ins
        .includes(:confidence_reporter)
        .order(check_in_week_start: :desc)
      @current_week_start = Date.current.beginning_of_week(:monday)
      flash.now[:alert] = 'Learnings are required.'
      render :done, status: :unprocessable_entity
      return
    end
    
    unless %w[hit hit_late miss].include?(completed_outcome)
      @check_ins = @goal.goal_check_ins
        .includes(:confidence_reporter)
        .order(check_in_week_start: :desc)
      @current_week_start = Date.current.beginning_of_week(:monday)
      flash.now[:alert] = 'Invalid completion outcome.'
      render :done, status: :unprocessable_entity
      return
    end
    
    # Determine confidence percentage
    confidence_percentage = (completed_outcome.in?(%w[hit hit_late])) ? 100 : 0
    
    # Get current week start
    current_week_start = Date.current.beginning_of_week(:monday)
    
    # Set PaperTrail whodunnit for version tracking
    PaperTrail.request.whodunnit = current_person.id.to_s
    
    # Create or update final check-in
    check_in = GoalCheckIn.find_or_initialize_by(
      goal: @goal,
      check_in_week_start: current_week_start
    )
    
    check_in.assign_attributes(
      confidence_percentage: confidence_percentage,
      confidence_reason: learnings,
      confidence_reporter: current_person
    )
    
    if check_in.save && @goal.update(completed_at: Time.current)
      redirect_url = params[:return_url] || organization_goal_path(@organization, @goal)
      redirect_to redirect_url,
                  notice: 'Goal marked as done successfully.'
    else
      @check_ins = @goal.goal_check_ins
        .includes(:confidence_reporter)
        .order(check_in_week_start: :desc)
      @current_week_start = Date.current.beginning_of_week(:monday)
      errors = check_in.errors.full_messages + @goal.errors.full_messages
      flash.now[:alert] = "Failed to complete goal: #{errors.join(', ')}"
      render :done, status: :unprocessable_entity
    end
  end
  
  private
  
  def set_goal
    # Load goal without scoping - policy will handle authorization checks
    @goal = Goal.find(params[:id])
  end
  
  def apply_timeframe_filter(goals, timeframe)
    return goals unless timeframe.present?
    return goals if timeframe == 'all'
    
    case timeframe
    when 'now'
      goals.timeframe_now
    when 'next'
      goals.timeframe_next
    when 'later'
      goals.timeframe_later
    else
      goals
    end
  end
  
  def apply_goal_type_filter(goals, goal_type)
    return goals unless goal_type.present?
    return goals if goal_type == 'all' || (goal_type.is_a?(Array) && goal_type.include?('all'))
    
    # Handle array of goal types
    goal_types = goal_type.is_a?(Array) ? goal_type : [goal_type]
    goals.where(goal_type: goal_types)
  end
  
  def apply_status_filter(goals, status)
    return goals unless status.present?
    return goals if status == 'all' || (status.is_a?(Array) && status.include?('all'))
    
      # Handle array of statuses
      if status.is_a?(Array)
        # Build query for multiple statuses
        status_scope = nil
        status.each do |s|
          case s
          when 'draft'
            scope = goals.draft
          when 'active'
            scope = goals.active
          else
            next
          end
          
          status_scope = status_scope ? status_scope.or(scope) : scope
        end
        status_scope || goals
      else
        case status
        when 'draft'
          goals.draft
        when 'active'
          goals.active
        else
          goals
        end
      end
  end
  
  def apply_spotlight_filter(goals, spotlight)
    return goals unless spotlight.present?
    return goals if spotlight == 'none'
    
    case spotlight
    when 'top_priority'
      goals.where.not(became_top_priority: nil)
    when 'recently_added'
      goals.where('created_at >= ?', 7.days.ago)
    when 'overdue'
      goals.active.where('most_likely_target_date < ?', Date.today)
    else
      goals
    end
  end
  
  def apply_sorting(goals, sort, direction)
    direction = direction == 'desc' ? :desc : :asc
    
    case sort
    when 'most_likely_target_date'
      goals.order(most_likely_target_date: direction)
    when 'earliest_target_date'
      goals.order(earliest_target_date: direction)
    when 'latest_target_date'
      goals.order(latest_target_date: direction)
    when 'created_at'
      goals.order(created_at: direction)
    when 'title'
      goals.order(title: direction)
    else
      goals.order(most_likely_target_date: :asc)
    end
  end
  
  def available_goal_owners
    options = []
    
    # Get company (root organization)
    company = @organization.root_company || @organization
    
    # Add current teammate (person themselves) - should be first/default
    # Find teammate in the company or any descendant organization
    company_descendant_ids = company.self_and_descendants.pluck(:id)
    current_teammate = current_person.teammates.find_by(organization_id: company_descendant_ids)
    if current_teammate
      options << ["Teammate: #{current_person.display_name}", "Teammate_#{current_teammate.id}"]
    end
    
    # Get teammates managed by current user in this organization (their employees)
    managed_teammates = Teammate.joins(:employment_tenures)
                                 .where(employment_tenures: { company: company, manager: current_person, ended_at: nil })
                                 .where.not(id: current_teammate&.id)
                                 .includes(:person)
                                 .distinct
                                 .order('people.last_name', 'people.first_name')
    
    managed_teammates.each do |teammate|
      options << ["Teammate: #{teammate.person.display_name}", "Teammate_#{teammate.id}"]
    end
    
    # Get departments and teams within the company where the user is a teammate
    # Only include organizations that are descendants of the company
    company_descendant_ids = company.self_and_descendants.pluck(:id)
    associated_orgs = Organization.joins(:teammates)
                                  .where(teammates: { person: current_person })
                                  .where(id: company_descendant_ids)
                                  .where.not(id: company.id) # Exclude company as we'll add it separately if needed
                                  .distinct
                                  .order(:name)
    
    associated_orgs.each do |org|
      type_label = org.company? ? 'Company' : (org.department? ? 'Department' : 'Team')
      options << ["#{type_label}: #{org.display_name}", "#{org.type}_#{org.id}"]
    end
    
    # Add company at the end
    if company.company?
      options << ["Company: #{company.display_name}", "Company_#{company.id}"]
    end
    
    options
  end
  helper_method :available_goal_owners
end

