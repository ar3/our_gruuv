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
      redirect_back(fallback_location: organizations_path, notice: "Switched to #{@organization.display_name}")
    else
      redirect_back(fallback_location: organizations_path, alert: "Failed to switch organization")
    end
  end
  
  def huddles_review
    # Parse date range parameters
    end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : Date.current
    start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : (end_date - 6.weeks)
    
    # Get all organizations in the hierarchy (self + all descendants)
    @hierarchy_organizations = @organization.self_and_descendants
    
    # Get huddles for all organizations in the hierarchy within the date range
    @huddles = Huddle.joins(:organization)
                      .where(organization: @hierarchy_organizations)
                      .where('started_at >= ? AND started_at <= ?', start_date.beginning_of_day, end_date.end_of_day)
                      .includes(:organization, :huddle_playbook, :huddle_feedbacks, :huddle_participants)
                      .order(:started_at)
    
    # Group huddles by calendar week
    @huddles_by_week = @huddles.group_by { |huddle| huddle.started_at.beginning_of_week }
    
    # Calculate weekly metrics
    @weekly_metrics = calculate_weekly_metrics(@huddles_by_week)
    
    # Calculate overall metrics for the period
    @overall_metrics = calculate_overall_metrics(@huddles)
    
    # Prepare chart data
    @chart_data = prepare_chart_data(@weekly_metrics)
    
    # Calculate playbook metrics
    @playbook_metrics = calculate_playbook_metrics(@huddles)
    
    @start_date = start_date
    @end_date = end_date
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
  
  def calculate_weekly_metrics(huddles_by_week)
    weekly_metrics = {}
    
    huddles_by_week.each do |week_start, huddles|
      total_huddles = huddles.count
      total_participants = huddles.sum { |h| h.huddle_participants.count }
      total_feedbacks = huddles.sum { |h| h.huddle_feedbacks.count }
      
      # Calculate distinct participants for this week
      distinct_participants = huddles.flat_map(&:huddle_participants).map(&:person).uniq(&:id)
      distinct_participant_count = distinct_participants.count
      distinct_participant_names = distinct_participants.map(&:display_name).sort
      
      # Calculate average ratings
      all_ratings = huddles.flat_map(&:huddle_feedbacks).map(&:nat_20_score).compact
      average_rating = all_ratings.any? ? (all_ratings.sum.to_f / all_ratings.count).round(1) : 0
      
      # Calculate participation rate
      participation_rate = total_participants > 0 ? (total_feedbacks.to_f / total_participants * 100).round(1) : 0
      
      weekly_metrics[week_start] = {
        total_huddles: total_huddles,
        total_participants: total_participants,
        distinct_participant_count: distinct_participant_count,
        distinct_participant_names: distinct_participant_names,
        total_feedbacks: total_feedbacks,
        average_rating: average_rating,
        participation_rate: participation_rate,
        huddles: huddles
      }
    end
    
    weekly_metrics
  end
  
  def calculate_overall_metrics(huddles)
    total_huddles = huddles.count
    total_participants = huddles.sum { |h| h.huddle_participants.count }
    total_feedbacks = huddles.sum { |h| h.huddle_feedbacks.count }
    
    # Calculate distinct participants
    distinct_participants = huddles.flat_map(&:huddle_participants).map(&:person).uniq(&:id)
    distinct_participant_count = distinct_participants.count
    distinct_participant_names = distinct_participants.map(&:display_name).sort
    
    # Calculate average ratings
    all_ratings = huddles.flat_map(&:huddle_feedbacks).map(&:nat_20_score).compact
    average_rating = all_ratings.any? ? (all_ratings.sum.to_f / all_ratings.count).round(1) : 0
    
    # Calculate participation rate
    participation_rate = total_participants > 0 ? (total_feedbacks.to_f / total_participants * 100).round(1) : 0
    
    # Calculate rating distribution
    rating_distribution = all_ratings.tally
    
    # Calculate conflict style distribution
    personal_conflict_styles = huddles.flat_map(&:huddle_feedbacks).map(&:personal_conflict_style).compact
    team_conflict_styles = huddles.flat_map(&:huddle_feedbacks).map(&:team_conflict_style).compact
    
    {
      total_huddles: total_huddles,
      total_participants: total_participants,
      distinct_participant_count: distinct_participant_count,
      distinct_participant_names: distinct_participant_names,
      total_feedbacks: total_feedbacks,
      average_rating: average_rating,
      participation_rate: participation_rate,
      rating_distribution: rating_distribution,
      personal_conflict_styles: personal_conflict_styles.tally,
      team_conflict_styles: team_conflict_styles.tally
    }
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
  
  def calculate_playbook_metrics(huddles)
    playbook_metrics = {}
    
    huddles.group_by(&:huddle_playbook).each do |playbook, playbook_huddles|
      next unless playbook # Skip huddles without playbooks
      
      total_huddles = playbook_huddles.count
      total_participants = playbook_huddles.sum { |h| h.huddle_participants.count }
      total_feedbacks = playbook_huddles.sum { |h| h.huddle_feedbacks.count }
      
      # Calculate distinct participants for this playbook
      distinct_participants = playbook_huddles.flat_map(&:huddle_participants).map(&:person).uniq(&:id)
      distinct_participant_count = distinct_participants.count
      distinct_participant_names = distinct_participants.map(&:display_name).sort
      
      # Calculate average ratings
      all_ratings = playbook_huddles.flat_map(&:huddle_feedbacks).map(&:nat_20_score).compact
      average_rating = all_ratings.any? ? (all_ratings.sum.to_f / all_ratings.count).round(1) : 0
      
      # Calculate participation rate
      participation_rate = total_participants > 0 ? (total_feedbacks.to_f / total_participants * 100).round(1) : 0
      
      # Calculate rating distribution
      rating_distribution = all_ratings.tally
      
      # Calculate conflict style distribution
      personal_conflict_styles = playbook_huddles.flat_map(&:huddle_feedbacks).map(&:personal_conflict_style).compact
      team_conflict_styles = playbook_huddles.flat_map(&:huddle_feedbacks).map(&:team_conflict_style).compact
      
      # Calculate weekly trends for this playbook
      weekly_trends = calculate_playbook_weekly_trends(playbook_huddles)
      
      playbook_metrics[playbook.id] = {
        id: playbook.id,
        display_name: playbook.display_name,
        organization_id: playbook.organization_id,
        organization_name: playbook.organization.display_name,
        total_huddles: total_huddles,
        total_participants: total_participants,
        distinct_participant_count: distinct_participant_count,
        distinct_participant_names: distinct_participant_names,
        total_feedbacks: total_feedbacks,
        average_rating: average_rating,
        participation_rate: participation_rate,
        rating_distribution: rating_distribution,
        personal_conflict_styles: personal_conflict_styles.tally,
        team_conflict_styles: team_conflict_styles.tally,
        weekly_trends: weekly_trends,
        huddles: playbook_huddles
      }
    end
    
    playbook_metrics
  end
  
  def calculate_playbook_weekly_trends(playbook_huddles)
    huddles_by_week = playbook_huddles.group_by { |huddle| huddle.started_at.beginning_of_week }
    
    weekly_trends = {}
    huddles_by_week.each do |week_start, huddles|
      all_ratings = huddles.flat_map(&:huddle_feedbacks).map(&:nat_20_score).compact
      average_rating = all_ratings.any? ? (all_ratings.sum.to_f / all_ratings.count).round(1) : 0
      
      total_participants = huddles.sum { |h| h.huddle_participants.count }
      total_feedbacks = huddles.sum { |h| h.huddle_feedbacks.count }
      participation_rate = total_participants > 0 ? (total_feedbacks.to_f / total_participants * 100).round(1) : 0
      
      weekly_trends[week_start] = {
        average_rating: average_rating,
        participation_rate: participation_rate,
        total_huddles: huddles.count
      }
    end
    
    weekly_trends
  end
end
