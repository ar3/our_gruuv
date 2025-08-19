class OrganizationsController < ApplicationController
  before_action :require_authentication
  before_action :set_organization, only: [:show, :edit, :update, :destroy, :switch, :huddles_review]
  
  def index
    @organizations = Organization.all.order(:type, :name)
    @current_organization = current_person.current_organization_or_default
  end


  
  def show
    # Load teams if this is a company
    @teams = @organization.children.teams.includes(:huddle_playbooks) if @organization.company?
    
    # Load playbooks for this organization
    @playbooks = @organization.huddle_playbooks.includes(:huddles)
    
    # Load stats for the three pillars
    load_organization_stats
  end
  
  def new
    @organization = Organization.new
    @organization.parent_id = params[:parent_id] if params[:parent_id].present?
  end
  
  def create
    @organization = Organization.new(organization_params)
    
    if @organization.save
      if @organization.parent.present?
        redirect_to organization_path(@organization.parent), notice: 'Child organization was successfully created.'
      else
        redirect_to organizations_path, notice: 'Organization was successfully created.'
      end
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @organization.update(organization_params)
      redirect_to organizations_path, notice: 'Organization was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @organization.destroy
    redirect_to organizations_path, notice: 'Organization was successfully deleted.'
  end
  
  def switch
    if current_person.switch_to_organization(@organization)
      redirect_to organization_path(@organization), notice: "Switched to #{@organization.display_name}"
    else
      redirect_to organizations_path, alert: "Failed to switch organization"
    end
  end
  
  def huddles_review
    # Parse date range parameters
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : (end_date - 6.weeks)
    
    # Use the stats service for all calculations
    stats_service = Huddles::StatsService.new(@organization, start_date..end_date)
    
    # Get all the stats we need
    @weekly_metrics = stats_service.weekly_stats
    @overall_metrics = stats_service.overall_stats
    @playbook_metrics = stats_service.playbook_stats
    
    # Prepare chart data
    @chart_data = prepare_chart_data(@weekly_metrics)
    
    @start_date = start_date
    @end_date = end_date
  end

  def refresh_slack_channels
    @organization = Organization.find(params[:id])
    
    if @organization.company?
      success = Companies::RefreshSlackChannelsJob.perform_and_get_result(@organization.id)
      
      if success
        redirect_to huddles_review_organization_path(@organization), notice: 'Slack channels refreshed successfully!'
      else
        redirect_to huddles_review_organization_path(@organization), alert: 'Failed to refresh Slack channels. Please check your Slack configuration.'
      end
    else
      redirect_to huddles_review_organization_path(@organization), alert: 'Slack channel management is only available for companies.'
    end
  end

  def update_huddle_review_channel
    @organization = Organization.find(params[:id])
    
    if @organization.company?
      @organization.huddle_review_notification_channel_id = params[:channel_id]
      
      if @organization.save
        redirect_to huddles_review_organization_path(@organization), notice: 'Huddle review notification channel updated successfully!'
      else
        redirect_to huddles_review_organization_path(@organization), alert: 'Failed to update notification channel.'
      end
    else
      redirect_to huddles_review_organization_path(@organization), alert: 'Channel management is only available for companies.'
    end
  end

  def trigger_weekly_notification
    @organization = Organization.find(params[:id])
    
    if @organization.company?
      success = Companies::WeeklyHuddlesReviewNotificationJob.perform_and_get_result(@organization.id)
      
      if success
        redirect_to huddles_review_organization_path(@organization), notice: 'Weekly notification sent successfully!'
      else
        redirect_to huddles_review_organization_path(@organization), alert: 'Failed to send weekly notification. Please check your Slack configuration.'
      end
    else
      redirect_to huddles_review_organization_path(@organization), alert: 'Weekly notifications are only available for companies.'
    end
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:id])
  end
  
  def organization_params
    params.require(:organization).permit(:name, :type, :parent_id)
  end
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access organizations.'
    end
  end
  
  def prepare_chart_data(weekly_metrics)
    # Prepare data for Highcharts
    weeks = weekly_metrics.keys.sort
    rating_data = weeks.map { |week| [week.to_time.to_i * 1000, weekly_metrics[week][:average_rating]] }
    participation_data = weeks.map { |week| [week.to_time.to_i * 1000, weekly_metrics[week][:participation_rate]] }
    huddles_data = weeks.map { |week| [week.to_time.to_i * 1000, weekly_metrics[week][:total_huddles]] }
    
    {
      weeks: weeks,
      rating_data: rating_data,
      participation_data: participation_data,
      huddles_data: huddles_data
    }
  end
  
  def load_organization_stats
    if @organization.company?
      # Organization stats
      @total_employees = @organization.employees.count
      # Get potential employees (people with access or huddle participation but no employment)
      access_people = @organization.person_organization_accesses.includes(:person)
        .where.not(person: @organization.employees)
        .map(&:person)
      
      huddle_people = @organization.huddle_participants
        .where.not(id: @organization.employees.select(:id))
      
      @total_potential_employees = (access_people + huddle_people).uniq.count
      @total_teams = @organization.children.teams.count
      @total_departments = @organization.children.departments.count
      
      # Align stats (positions and assignments across all sub-organizations)
      @total_positions = @organization.positions.count + @organization.children.sum { |child| child.positions.count }
      @total_assignments = @organization.assignments.count + @organization.children.sum { |child| child.assignments.count }
      
      # Collaborate stats (huddles and ratings)
      this_week_start = Time.current.beginning_of_week(:monday)
      this_week_end = Time.current.end_of_week(:sunday)
      
      @active_huddles_this_week = @organization.huddles.where(started_at: this_week_start..this_week_end, expires_at: Time.current..)
      @total_participants_this_week = @active_huddles_this_week.joins(:huddle_participants).count
      @average_rating_this_week = @active_huddles_this_week.joins(:huddle_feedbacks)
        .average('(informed_rating + connected_rating + goals_rating + valuable_rating) / 4.0')
        &.round(1) || 0
      
      @total_huddles_all_time = @organization.huddles.count
      @total_participants_all_time = @organization.huddles.joins(:huddle_participants).count
      @average_rating_all_time = @organization.huddles.joins(:huddle_feedbacks)
        .average('(informed_rating + connected_rating + goals_rating + valuable_rating) / 4.0')
        &.round(1) || 0
    end
  end
end
