class Organizations::GoalsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_goal, only: [:show, :edit, :update, :destroy, :start, :check_in, :set_timeframe, :done, :complete, :undelete, :weekly_update]
  
  after_action :verify_authorized
  after_action :verify_policy_scoped, only: :index
  
  def index
    authorize company, :view_goals?
    
    # Check for special filters
    @everyone_in_company_filter = params[:owner_id] == 'everyone_in_company'
    @created_by_me_filter = params[:owner_id] == 'created_by_me'

    # Parse owner_id if it's in format "Type_ID" (e.g., "CompanyTeammate_123", "Company_456")
    if !@everyone_in_company_filter && !@created_by_me_filter && params[:owner_id].present? && params[:owner_id].include?('_') && params[:owner_type].blank?
      owner_type, owner_id = params[:owner_id].split('_', 2)
      params[:owner_type] = owner_type
      params[:owner_id] = owner_id
    end
    # Dropdown uses "Company" label but Goal stores owner_type as Organization
    params[:owner_type] = 'Organization' if params[:owner_type] == 'Company'

    # Current teammate already ensured by ensure_teammate_matches_organization
    current_teammate = current_company_teammate

    # Default to logged in user if no owner is selected (unless using special filters)
    unless @everyone_in_company_filter || @created_by_me_filter || (params[:owner_type].present? && params[:owner_id].present?)
      if current_teammate
        params[:owner_type] = 'CompanyTeammate'
        params[:owner_id] = current_teammate.id.to_s
      else
        @goals = policy_scope(Goal.none)
        @view_style = params[:view] || 'hierarchical-collapsible'
        @view_style = 'hierarchical-collapsible' unless %w[table cards list network tree nested timeline hierarchical-indented hierarchical-collapsible].include?(@view_style)
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
          show_completed: params[:show_completed],
          prompt_id: params[:prompt_id].presence
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

    # Apply owner or special filter
    if @everyone_in_company_filter
      # Filter for goals with "everyone_in_company" privacy level (ignore owner).
      # Do not apply .active here — FilterQuery already applied show_deleted/show_completed;
      # we want to show all public goals (draft, active, completed) per user prefs.
      @goals = @goals.where(privacy_level: 'everyone_in_company')
    elsif @created_by_me_filter
      # Filter for goals created by the current teammate
      @goals = @goals.where(creator: current_teammate)
    else
      # Filter by owner
      @goals = @goals.where(owner_type: params[:owner_type], owner_id: params[:owner_id])
    end

    # Apply prompt filter: restrict to goals associated with this prompt + their descendant hierarchy
    if params[:prompt_id].present?
      company = @organization.root_company || @organization
      @filter_prompt = Prompt.find_by(id: params[:prompt_id])
      @filter_prompt = nil if @filter_prompt && @filter_prompt.company_teammate.organization.id != company.id
      if @filter_prompt
        prompt_goal_ids = @filter_prompt.goals.pluck(:id)
        all_ids = prompt_goal_ids.dup
        current_level = prompt_goal_ids.dup
        while current_level.any?
          child_ids = GoalLink.where(parent_id: current_level).pluck(:child_id).uniq
          child_ids.each { |id| all_ids << id unless all_ids.include?(id) }
          current_level = child_ids
        end
        @goals = @goals.where(id: all_ids)
      end
    end
    
    # Set default spotlight
    spotlight_param = params[:spotlight]
    if spotlight_param.blank? || spotlight_param == 'none'
      spotlight_param = 'goals_overview'
    end
    
    # Calculate spotlight stats for goals_overview (before other filters)
    if spotlight_param == 'goals_overview'
      if @everyone_in_company_filter
        all_goals_for_filter = policy_scope(Goal).where(privacy_level: 'everyone_in_company')
      elsif @created_by_me_filter
        all_goals_for_filter = policy_scope(Goal).where(creator: current_teammate)
      else
        all_goals_for_filter = policy_scope(Goal).where(owner_type: params[:owner_type], owner_id: params[:owner_id])
      end
      all_goals_for_filter = Goals::FilterQuery.new(all_goals_for_filter).call(
        show_deleted: params[:show_deleted] == '1',
        show_completed: params[:show_completed] == '1'
      )
      @spotlight_stats = helpers.calculate_goals_overview_stats(all_goals_for_filter)
    end
    
    # Apply filters
    @goals = apply_timeframe_filter(@goals, params[:timeframe])
    @goals = apply_goal_type_filter(@goals, params[:goal_type])
    @goals = apply_status_filter(@goals, params[:status])
    @goals = apply_spotlight_filter(@goals, spotlight_param)

    # Apply sorting
    @goals = apply_sorting(@goals, params[:sort], params[:direction])
    
    # Set view style
    @view_style = params[:view] || 'hierarchical-collapsible'
    @view_style = 'hierarchical-collapsible' unless %w[table cards list network tree nested timeline hierarchical-indented hierarchical-collapsible].include?(@view_style)
    
    # Eager load links and owner (with person for CompanyTeammate) for table/cards/list to avoid N+1
    if @view_style.in?(%w[table cards list])
      @goals = @goals.includes(:outgoing_links, :incoming_links, owner: :person)
    end

    # Eager load owner (with person for CompanyTeammate) and prompt associations for hierarchical views
    # (goal node shows owner image/name and "In reflection: ..." to avoid N+1)
    if @view_style.in?(%w[hierarchical-collapsible hierarchical-indented])
      @goals = @goals.includes(owner: :person, prompt_goals: { prompt: :prompt_template })
    end
    
    # For hierarchical-indented view, load most recent check-ins for display
    if @view_style == 'hierarchical-indented'
      goal_ids = @goals.pluck(:id)
      @most_recent_check_ins_by_goal = GoalCheckIn
        .where(goal_id: goal_ids)
        .includes(:confidence_reporter, :goal)
        .recent
        .group_by(&:goal_id)
        .transform_values { |check_ins| check_ins.first }
    end
    
    # For hierarchical-collapsible view, build hierarchy with check-ins and permissions
    if @view_style == 'hierarchical-collapsible'
      @goal_hierarchy = Goals::HierarchyWithCheckInsQuery.new(
        goals: @goals,
        current_person: current_person,
        organization: @organization
      ).call
      
      # Also expose individual maps for fallback rendering
      @most_recent_check_ins_by_goal = @goal_hierarchy[:most_recent_check_ins_by_goal]
      @current_week_check_ins_by_goal = @goal_hierarchy[:current_week_check_ins_by_goal]
      @can_check_in_goals = @goal_hierarchy[:can_check_in_goals]
    end
    
    # Performance check for visualizations
    @goal_count = @goals.count
    @show_performance_warning = @goal_count > 100 && %w[network tree nested timeline].include?(@view_style)

    # Store filter/sort params for view
    @current_filters = {
      timeframe: params[:timeframe],
      goal_type: params[:goal_type],
      status: params[:status],
      sort: params[:sort] || 'smart_sort',
      direction: params[:direction],
      view: @view_style,
      spotlight: spotlight_param,
      owner_type: @everyone_in_company_filter ? nil : params[:owner_type],
      owner_id: @everyone_in_company_filter ? 'everyone_in_company' : params[:owner_id],
      show_deleted: params[:show_deleted],
      show_completed: params[:show_completed],
      prompt_id: params[:prompt_id].presence,
      return_url: params[:return_url].presence,
      return_text: params[:return_text].presence
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
    
    # Load prompt associations for display
    @prompt_goals = @goal.prompt_goals.includes(:prompt, prompt: :prompt_template).order(created_at: :desc)
  end
  
  def weekly_update
    authorize @goal, :show?
    
    # Load all check-ins chronologically (oldest first) for display
    @all_check_ins = @goal.goal_check_ins
      .includes(:confidence_reporter)
      .order(check_in_week_start: :asc)
    
    # Load check-in data for current week
    @current_week_start = Date.current.beginning_of_week(:monday)
    @current_check_in = @goal.goal_check_ins
      .for_week(@current_week_start)
      .includes(:confidence_reporter)
      .first
    
    # Progress chart: thresholds + actual check-ins (only when goal has target dates and started_at)
    @progress_chart_data = Goals::ProgressChartDataBuilder.call(goal: @goal)
    
    # Set return_url and return_text from params (for mode switcher navigation)
    @return_url = params[:return_url] || organization_goal_path(@organization, @goal)
    @return_text = params[:return_text] || 'Back to Goal'
  end
  
  def new
    company = @organization.root_company || @organization
    @goal = Goal.new(company: company)
    authorize @goal
    
    @form = GoalForm.new(@goal)
    @form.current_person = current_person
    @form.current_teammate = current_company_teammate
    # Set defaults
    @form.goal_type = 'inspirational_objective' # Default to objective
    @form.privacy_level = 'only_creator_owner_and_managers'
    @form.earliest_target_date = nil
    @form.latest_target_date = nil
    # Default owner to current teammate if they have a CompanyTeammate record
    # Only set default if not provided in query string params
    unless params[:owner_id].present? || params[:owner_type].present?
      if @form.current_teammate
        @form.owner_id = "CompanyTeammate_#{@form.current_teammate.id}"
      end
    else
      # Parse owner from query string if provided
      if params[:owner_id].present?
        if params[:owner_id].include?('_')
          # Already in unified format
          @form.owner_id = params[:owner_id]
        elsif params[:owner_type].present?
          @form.owner_type = params[:owner_type]
          @form.owner_id = params[:owner_id]
        end
      end
    end
    authorize @goal
  end
  
  def create
    authorize Goal.new

    company = @organization.root_company || @organization
    @goal = Goal.new(company: company)
    @form = GoalForm.new(@goal)
    @form.current_person = current_person
    @form.current_teammate = current_company_teammate

    goal_params = params[:goal] || {}
    
    if @form.validate(goal_params) && @form.save
      redirect_to weekly_update_organization_goal_path(@organization, @goal), 
        return_text: 'Edit Goal / Add Child Goals',          
        notice: 'Goal was successfully created.'
    else
      flash.now[:alert] = @form.errors.full_messages.join(', ')
      render :new, status: :unprocessable_entity
    end
  end

  def bulk_new
    authorize Goal.new
    # Resolve owner from params, or default to current teammate (already ensured by ensure_teammate_matches_organization)
    @owner = resolve_owner_for_bulk(current_company_teammate)
    @owner ||= current_company_teammate
    unless @owner
      redirect_to organization_goals_path(@organization),
                  alert: 'You must be a company teammate to bulk create goals.'
      return
    end
    @owner_param = build_owner_param_for_bulk
  end

  def bulk_create
    authorize Goal.new
    @owner = resolve_owner_for_bulk(current_company_teammate)
    unless @owner
      redirect_to organization_goals_path(@organization),
                  alert: 'Please select an owner to bulk create goals.'
      return
    end

    bulk_goal_titles = params[:bulk_goal_titles].to_s
    parse_result = Goals::ParseService.new(bulk_goal_titles, 'quantitative_key_result').call

    if parse_result[:errors].any?
      redirect_to bulk_new_organization_goals_path(@organization, owner_id: build_owner_param_for_bulk),
                  alert: parse_result[:errors].join(' ')
      return
    end

    if parse_result[:goals].empty?
      redirect_to bulk_new_organization_goals_path(@organization, owner_id: build_owner_param_for_bulk),
                  alert: 'Please enter at least one goal.'
      return
    end

    # Determine privacy level based on owner type:
    # - Organization owner (Company/Department/Team) -> everyone_in_company
    # - Teammate owner -> only_creator_owner_and_managers
    privacy = privacy_level_for_owner(@owner)

    service = Goals::BulkCreateUnlinkedService.new(
      @organization,
      current_person,
      current_company_teammate,
      @owner,
      parse_result[:goals],
      default_goal_type: 'quantitative_key_result',
      privacy_level: privacy
    )

    if service.call
      count = service.created_goals.size
      redirect_to organization_goals_path(@organization, owner_id: build_owner_param_for_bulk),
                  notice: "#{count} #{'goal'.pluralize(count)} created successfully."
    else
      redirect_to bulk_new_organization_goals_path(@organization, owner_id: build_owner_param_for_bulk),
                  alert: service.errors.join(' ')
    end
  end
  
  def edit
    authorize @goal
    
    @form = GoalForm.new(@goal)
    @form.current_person = current_person
    @form.current_teammate = current_company_teammate

    # Preload linked goals for display (read-only on edit page)
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
  
  def update
    authorize @goal

    @form = GoalForm.new(@goal)
    @form.current_person = current_person
    @form.current_teammate = current_company_teammate
    
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
    
    # Check authorization for goal update if target date is being updated
    if params[:most_likely_target_date].present?
      authorize @goal, :update?
    end
    
    result = Goals::CheckInService.call(
      goal: @goal,
      current_person: current_person,
      confidence_percentage: params[:confidence_percentage],
      confidence_reason: params[:confidence_reason],
      most_likely_target_date: params[:most_likely_target_date]
    )
    
    return_url = params[:return_url] || organization_goal_path(@organization, @goal)
    
    if result.ok?
      notice = 'Check-in saved successfully.'
      notice += ' Target date updated.' if result.value[:target_date_updated]
      redirect_to return_url, notice: notice
    else
      redirect_to return_url, alert: "Failed to save check-in: #{result.error}"
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
    @form.current_teammate = current_company_teammate

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
    
    # Parse owner_id if it's in format "Type_ID" (e.g., "CompanyTeammate_123", "Company_456")
    if params[:owner_id].present? && params[:owner_id].include?('_') && params[:owner_type].blank?
      owner_type, owner_id = params[:owner_id].split('_', 2)
      params[:owner_type] = owner_type
      params[:owner_id] = owner_id
    end
    # Dropdown uses "Company" label but Goal stores owner_type as Organization
    params[:owner_type] = 'Organization' if params[:owner_type] == 'Company'
    
    # Default to logged in user if no owner is selected
    unless params[:owner_type].present? && params[:owner_id].present?
      if current_company_teammate
        params[:owner_type] = 'CompanyTeammate'
        params[:owner_id] = current_company_teammate.id.to_s
      end
    end
    
    # Load current state from params
    @current_filters = {
      timeframe: params[:timeframe],
      goal_type: params[:goal_type],
      status: params[:status],
      sort: params[:sort] || 'smart_sort',
      direction: params[:direction] || 'asc',
      view: params[:view] || 'hierarchical-collapsible',
      spotlight: params[:spotlight] || 'goals_overview',
      owner_type: params[:owner_type],
      owner_id: params[:owner_id],
      show_deleted: params[:show_deleted],
      show_completed: params[:show_completed]
    }
    
    # Validate view style
    valid_views = %w[table cards list network tree nested timeline hierarchical-indented hierarchical-collapsible]
    @current_filters[:view] = 'hierarchical-collapsible' unless valid_views.include?(@current_filters[:view])
    
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

  # Departments for goal owner dropdown: hierarchically and alphabetically (root first, then children by name).
  # Example: AAA, BBB, BBB > Sub-B1, BBB > Sub-B2, CCC, CCC > Sub-C1, DDD, EEE
  def department_goal_owner_options(company)
    result = []
    roots = Department.where(company: company).active.root_departments.ordered
    append_departments_for_goal_owners(roots, result)
    result
  end

  def append_departments_for_goal_owners(departments, result)
    departments.each do |dept|
      next unless dept.display_name.present? && dept.id.present?
      result << ["Department: #{dept.display_name}", "Department_#{dept.id}"]
      children = dept.child_departments.active.ordered
      append_departments_for_goal_owners(children, result) if children.any?
    end
  end

  def resolve_owner_for_bulk(current_teammate)
    owner_id_param = params[:owner_id].to_s
    if owner_id_param.include?('_')
      owner_type, owner_id = owner_id_param.split('_', 2)
    else
      owner_type = params[:owner_type]
      owner_id = params[:owner_id]
    end
    return current_teammate if owner_type.blank? || owner_id.blank?

    case owner_type
    when 'CompanyTeammate'
      CompanyTeammate.find_by(id: owner_id)
    when 'Organization', 'Company'
      Organization.find_by(id: owner_id)
    when 'Department'
      Department.find_by(id: owner_id)
    when 'Team'
      Team.find_by(id: owner_id)
    else
      nil
    end
  end

  def build_owner_param_for_bulk
    return nil unless @owner
    owner_type = @owner.is_a?(CompanyTeammate) ? 'CompanyTeammate' : @owner.class.name
    "#{owner_type}_#{@owner.id}"
  end
  
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
    when 'smart_sort'
      # Smart sort: by parent goal, then day of most_likely_target_date, then alphabetically by name
      # Need to load goals with parent goals and sort in Ruby
      goals_array = goals.includes(:linking_goals).to_a
      
      # Build cache of first parent goal for each goal
      parent_goals_cache = {}
      goals_array.each do |goal|
        first_parent = goal.linking_goals.sort_by(&:title).first
        parent_goals_cache[goal.id] = first_parent&.title&.downcase || ''
      end
      
      # Sort by parent goal title, then day of most_likely_target_date, then goal title
      sorted_goals = goals_array.sort_by do |goal|
        parent_goal_title = parent_goals_cache[goal.id] || ''
        date_day = goal.most_likely_target_date&.day || 99
        goal_title = goal.title&.downcase || ''
        [parent_goal_title, date_day, goal_title]
      end
      
      # Reverse if descending direction
      sorted_goals = sorted_goals.reverse if direction == :desc
      
      # Return as ActiveRecord relation with proper ordering using CASE statement
      goal_ids = sorted_goals.map(&:id)
      if goal_ids.any?
        order_clause = goal_ids.map.with_index { |id, i| "WHEN #{id} THEN #{i}" }.join(' ')
        Goal.where(id: goal_ids).order(Arel.sql("CASE goals.id #{order_clause} END"))
      else
        Goal.none
      end
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
      # Default to smart_sort if sort is nil or unknown
      apply_sorting(goals, 'smart_sort', direction)
    end
  end
  
  def available_goal_owners
    options = []
    company = @organization.root_company || @organization

    # Filter-only options (index page: view all / view mine)
    if company.display_name.present?
      options << ["All goals visible to everyone at #{company.display_name}", "everyone_in_company"]
    end
    options << ["All goals created by me", "created_by_me"]

    # 1) Viewing teammate first (already ensured by ensure_teammate_matches_organization)
    current_teammate = current_company_teammate
    if current_teammate && current_person&.display_name.present?
      options << ["Teammate: #{current_person.display_name}", "CompanyTeammate_#{current_teammate.id}"]
    end

    # 2) Other teammates alphabetically
    current_manager_teammate = current_person.teammates
                                             .where(organization_id: company.id)
                                             .first
    managed_teammates = if current_manager_teammate
      CompanyTeammate.joins(:employment_tenures)
                     .where(employment_tenures: { company: company, manager_teammate_id: current_manager_teammate.id, ended_at: nil })
                     .where.not(id: current_teammate&.id)
                     .includes(:person)
                     .distinct
                     .order('people.last_name', 'people.first_name')
    else
      CompanyTeammate.none
    end
    managed_teammates.each do |teammate|
      next unless teammate.person&.display_name.present? && teammate.id.present?
      options << ["Teammate: #{teammate.person.display_name}", "CompanyTeammate_#{teammate.id}"]
    end

    # 3) Company
    if company.display_name.present? && company.id.present?
      options << ["Company: #{company.display_name}", "Company_#{company.id}"]
    end

    # 4) Departments: hierarchically and alphabetically (root first, then children alphabetically)
    options.concat(department_goal_owner_options(company))

    # Teams (alphabetically)
    Team.where(company: company).ordered.each do |t|
      next unless t.display_name.present? && t.id.present?
      options << ["Team: #{t.display_name}", "Team_#{t.id}"]
    end

    options.reject { |label, value| label.blank? || value.blank? || value.nil? }
  end
  helper_method :available_goal_owners

  # Value for the primary filter dropdown that matches option values (dropdown uses "Company_" but store uses Organization)
  def primary_filter_select_value
    return nil if @current_filters[:owner_type].blank? || @current_filters[:owner_id].blank?
    type = @current_filters[:owner_type]
    type = 'Company' if type == 'Organization'
    "#{type}_#{@current_filters[:owner_id]}"
  end
  helper_method :primary_filter_select_value

  # Grouped options for index primary filter: [ [ "Filter", [ [label, value], ... ] ], [ "Teammates", ... ], ... ]
  def available_goal_owners_grouped
    company = @organization.root_company || @organization
    groups = []

    filter_opts = []
    filter_opts << ["All goals visible to everyone at #{company.display_name}", "everyone_in_company"] if company.display_name.present?
    filter_opts << ["All goals created by me", "created_by_me"]
    groups << ["Filter", filter_opts] if filter_opts.any?

    teammate_opts = []
    current_teammate = current_company_teammate
    if current_teammate && current_person&.display_name.present?
      teammate_opts << ["Teammate: #{current_person.display_name}", "CompanyTeammate_#{current_teammate.id}"]
    end
    current_manager_teammate = current_person.teammates.where(organization_id: company.id).first
    managed_teammates = if current_manager_teammate
      CompanyTeammate.joins(:employment_tenures)
                     .where(employment_tenures: { company: company, manager_teammate_id: current_manager_teammate.id, ended_at: nil })
                     .where.not(id: current_teammate&.id)
                     .includes(:person)
                     .distinct
                     .order('people.last_name', 'people.first_name')
    else
      CompanyTeammate.none
    end
    managed_teammates.each do |teammate|
      next unless teammate.person&.display_name.present? && teammate.id.present?
      teammate_opts << ["Teammate: #{teammate.person.display_name}", "CompanyTeammate_#{teammate.id}"]
    end
    groups << ["Teammates", teammate_opts] if teammate_opts.any?

    company_opts = []
    company_opts << ["Company: #{company.display_name}", "Company_#{company.id}"] if company.display_name.present? && company.id.present?
    groups << ["Company", company_opts] if company_opts.any?

    dept_opts = department_goal_owner_options(company)
    groups << ["Departments", dept_opts] if dept_opts.any?

    team_opts = Team.where(company: company).ordered.filter_map do |t|
      next unless t.display_name.present? && t.id.present?
      ["Team: #{t.display_name}", "Team_#{t.id}"]
    end
    groups << ["Teams", team_opts] if team_opts.any?

    groups
  end
  helper_method :available_goal_owners_grouped

  # Returns goal owners for bulk create form (excludes filter options that aren't actual owners)
  def available_goal_owners_for_bulk
    available_goal_owners.reject { |_label, value| value.in?(['everyone_in_company', 'created_by_me']) }
  end
  helper_method :available_goal_owners_for_bulk

  # Determines the appropriate privacy level based on owner type
  def privacy_level_for_owner(owner)
    if owner.is_a?(Organization) || owner.is_a?(Department) || owner.is_a?(Team)
      'everyone_in_company'
    else
      'only_creator_owner_and_managers'
    end
  end
end

