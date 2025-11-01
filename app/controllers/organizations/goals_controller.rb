class Organizations::GoalsController < Organizations::OrganizationNamespaceBaseController
  before_action :authenticate_person!
  before_action :set_goal, only: [:show, :edit, :update, :destroy]
  
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index
  
  def index
    # Get current teammate for this organization
    current_teammate = current_person.teammates.find_by(organization: @organization)
    
    # Start with goals visible to the teammate
    @goals = policy_scope(Goal).for_teammate(current_teammate)
    
    # Apply filters
    @goals = apply_timeframe_filter(@goals, params[:timeframe])
    @goals = apply_goal_type_filter(@goals, params[:goal_type])
    @goals = apply_status_filter(@goals, params[:status])
    @goals = apply_spotlight_filter(@goals, params[:spotlight])
    
    # Apply sorting
    @goals = apply_sorting(@goals, params[:sort], params[:direction])
    
    # Set view style
    @view_style = params[:view] || 'table'
    @view_style = 'table' unless %w[table cards list].include?(@view_style)
    
    # Store filter/sort params for view
    @current_filters = {
      timeframe: params[:timeframe],
      goal_type: params[:goal_type],
      status: params[:status],
      sort: params[:sort],
      direction: params[:direction],
      view: @view_style,
      spotlight: params[:spotlight]
    }
  end
  
  def show
    authorize @goal
  end
  
  def new
    @goal = Goal.new
    @form = GoalForm.new(@goal)
    @form.current_person = current_person
    @form.current_teammate = current_person.teammates.find_by(organization: @organization)
    # Set defaults
    @form.goal_type = 'inspirational_objective'
    @form.privacy_level = 'everyone_in_company'
    # Default owner to current person if they have a teammate record
    if @form.current_teammate
      @form.owner_type = 'Person'
      @form.owner_id = current_person.id
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
  
  private
  
  def set_goal
    # Goals can belong to Person or Organization, so we need to find them differently
    # We'll search by ID across all goals (policy scope will handle authorization)
    @goal = Goal.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    # If not found, it might be due to soft delete or authorization
    # Let policy handle this
    @goal = Goal.with_deleted.find(params[:id]) rescue nil
    raise ActiveRecord::RecordNotFound unless @goal
  end
  
  def apply_timeframe_filter(goals, timeframe)
    return goals unless timeframe.present?
    return goals if timeframe == 'all'
    
    case timeframe
    when 'now'
      goals.now
    when 'next'
      goals.next_timeframe
    when 'later'
      goals.later
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
        when 'completed'
          scope = goals.completed
        when 'cancelled'
          scope = goals.cancelled
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
      when 'completed'
        goals.completed
      when 'cancelled'
        goals.cancelled
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
    
    # Add current user
    options << ["Person: #{current_person.display_name}", "Person_#{current_person.id}"]
    
    # Get company (root organization)
    company = @organization.root_company || @organization
    if company.company?
      options << ["Organization: #{company.display_name}", "Organization_#{company.id}"]
    end
    
    # Get direct reports (people managed by current user in this organization)
    direct_reports = Person.joins(teammates: :employment_tenures)
                           .where(employment_tenures: { company: company, manager: current_person, ended_at: nil })
                           .distinct
                           .order(:last_name, :first_name)
    
    direct_reports.each do |person|
      options << ["Person: #{person.display_name}", "Person_#{person.id}"]
    end
    
    # Get departments and teams the current user is associated with via teammates
    # This includes organizations where the user has a teammate record
    associated_orgs = Organization.joins(:teammates)
                                  .where(teammates: { person: current_person })
                                  .where.not(id: company.id) # Exclude company as we already added it
                                  .distinct
                                  .order(:name)
    
    associated_orgs.each do |org|
      options << ["Organization: #{org.display_name}", "Organization_#{org.id}"]
    end
    
    options
  end
  helper_method :available_goal_owners
end

