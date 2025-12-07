class OrganizationsController < Organizations::OrganizationNamespaceBaseController
  layout 'authenticated-horizontal-navigation'
  before_action :require_authentication, except: [:pundit_healthcheck]
  
  def index
    @organizations = current_company_teammate.person.available_organizations
    @followable_organizations = current_company_teammate.person.followable_organizations
    @current_organization = current_company_teammate.organization
  end
  
  def switch_page
    # Only show company organizations that the user has access to
    @organizations = current_company_teammate.person.available_organizations.companies.order(:type, :name)
    @current_organization = current_company_teammate.organization
    
    # Debugging data collection
    @debug_info = {
      session_teammate_id: session[:current_company_teammate_id],
      current_teammate_id: current_company_teammate&.id,
      current_teammate_type: current_company_teammate&.type,
      current_person_id: current_person&.id,
      current_organization_id: current_organization&.id,
      current_organization_name: current_organization&.name,
      session_keys: session.keys.grep(/teammate|person|organization/),
      impersonating: impersonating?,
      impersonating_teammate_id: session[:impersonating_teammate_id],
      user_agent: request.user_agent,
      secure_cookies: request.ssl?,
      session_id_available: session.id.present?,
      rails_env: Rails.env
    }
    
    # Collect teammate debug info for each organization
    @teammate_debug_info = {}
    @organizations.each do |org|
      root_company = org.root_company || org
      teammate = current_person.teammates.find_by(organization: root_company)
      
      @teammate_debug_info[org.id] = {
        teammate_id: teammate&.id,
        teammate_type: teammate&.type,
        teammate_exists: teammate.present?,
        root_company_id: root_company.id,
        root_company_name: root_company.name,
        first_employed_at: teammate&.first_employed_at,
        last_terminated_at: teammate&.last_terminated_at,
        is_terminated: teammate&.last_terminated_at.present?,
        is_active: teammate&.last_terminated_at.nil?,
        will_create_new: teammate.nil?,
        created_at: teammate&.created_at,
        is_company_teammate: teammate.is_a?(CompanyTeammate)
      }
    end
  end
  
  def dashboard
    @current_person = current_company_teammate.person
    @recent_huddles = Huddle.joins(huddle_participants: :teammate)
                            .where(teammates: { person: @current_person })
                            .recent
                            .limit(5)
    
    # Load check-ins data for hero cards
    load_check_ins_dashboard_stats
    
    # Organization-specific dashboard content will go here
    load_organization_dashboard_stats
  end
  
  def follow
    organization = Organization.find(params[:id])
    
    if current_company_teammate.person.can_follow_organization?(organization)
      # Create a follower teammate (no employment dates)
      teammate = current_company_teammate.person.teammates.create!(
        organization: organization,
        type: 'CompanyTeammate'
      )
      
      # If this is the first teammate, set it as current
      if current_company_teammate.person.active_teammates.count == 1
        # Ensure it's a CompanyTeammate for root company
        company_teammate = ensure_company_teammate(teammate) || teammate
        session[:current_company_teammate_id] = company_teammate.id
      end
      
      redirect_to organizations_path, notice: "You are now following #{organization.name}."
    else
      redirect_to organizations_path, alert: "You cannot follow this organization."
    end
  end
  
  def unfollow
    organization = Organization.find(params[:id])
    teammate = current_company_teammate.person.teammates.find_by(organization: organization)
    
    if teammate&.follower?
      # If we're unfollowing the current teammate, switch to another one
      if teammate.id == current_company_teammate.id
        other_teammate = current_company_teammate.person.active_teammates.where.not(id: teammate.id).first
        if other_teammate
          # Ensure it's a CompanyTeammate for root company
          company_teammate = ensure_company_teammate(other_teammate) || other_teammate
          session[:current_company_teammate_id] = company_teammate.id
        else
          # No other teammates - ensure "OurGruuv Demo" teammate exists (already returns CompanyTeammate)
          new_teammate = ensure_teammate_for_person(current_company_teammate.person)
          session[:current_company_teammate_id] = new_teammate.id
        end
      end
      
      teammate.destroy
      redirect_to organizations_path, notice: "You are no longer following #{organization.name}."
    else
      redirect_to organizations_path, alert: "You are not following this organization or cannot unfollow."
    end
  end

  
  def show
    # Load teams if this is a company
    @teams = @organization.children.teams.includes(:huddle_playbooks) if @organization.company?
    
    # Load playbooks for this organization
    @playbooks = @organization.huddle_playbooks.includes(:huddles)
    
    # Load stats for the three pillars
    load_organization_stats
    
  end
  
  def refresh_slack_profiles
    authorize @organization, :manage_employment?, policy_class: OrganizationPolicy
    
    result = SlackProfileMatcherService.new.call(@organization)
    
    if result[:success]
      matched_count = result[:matched_count]
      total_teammates = result[:total_teammates]
      errors = result[:errors]
      
      notice_message = "Successfully matched #{matched_count} out of #{total_teammates} teammates with Slack profiles."
      notice_message += " #{errors.length} errors occurred." if errors.any?
      
      redirect_to organization_slack_path(@organization), notice: notice_message
    else
      redirect_to organization_slack_path(@organization), alert: "Failed to refresh Slack profiles: #{result[:error]}"
    end
  end

  def new_refresh_names
    authorize @organization, :manage_employment?, policy_class: OrganizationPolicy
    redirect_to new_organization_bulk_sync_event_path(@organization, bulk_sync_event: { type: 'BulkSyncEvent::RefreshNamesSync' })
  end

  def new_refresh_slack
    authorize @organization, :manage_employment?, policy_class: OrganizationPolicy
    redirect_to new_organization_bulk_sync_event_path(@organization, bulk_sync_event: { type: 'BulkSyncEvent::RefreshSlackSync' })
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
    # Get root_company of target organization
    root_company = @organization.root_company || @organization
    
    # Find or create teammate for the root_company
    teammate = current_company_teammate.person.teammates.find_or_create_by!(
      organization: root_company
    ) do |t|
      t.type = 'CompanyTeammate'
      t.first_employed_at = nil
      t.last_terminated_at = nil
    end
    
    # Ensure it's a CompanyTeammate for root company before setting session
    company_teammate = ensure_company_teammate(teammate) || teammate
    session[:current_company_teammate_id] = company_teammate.id
    
    redirect_to organization_path(@organization), notice: "Switched to #{@organization.display_name}"
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

  def celebrate_milestones
    # Get milestones attained in the last 90 days within this organization
    @recent_milestones = TeammateMilestone.joins(:ability, :teammate, :certified_by)
                                       .where(abilities: { organization: @organization })
                                       .where(attained_at: 90.days.ago..Time.current)
                                       .includes(:ability, :teammate, :certified_by)
                                       .order(attained_at: :desc)
    
    # Group by person for easier display
    @milestones_by_person = @recent_milestones.group_by { |milestone| milestone.teammate.person }
    
    # Get counts for the page
    @total_milestones = @recent_milestones.count
    @unique_people = @milestones_by_person.keys.count
  end

  def accountability_chart
    authorize @organization, :show?
    
    query = OrganizationHierarchyQuery.new(organization: @organization)
    @chart_data = query.call
  end

  def pundit_healthcheck
    # Skip authentication and organization setup for this debugging route
    health_data = Debug::PunditHealthCheckService.call(self)
    
    # Organization Context Sources
    org_context = health_data[:organization_context]
    @route_organization = org_context[:route_organization]
    @org_from_params = org_context[:org_from_params]
    @org_from_instance = org_context[:org_from_instance]
    @org_from_teammate = org_context[:org_from_teammate]
    @org_from_helper = org_context[:org_from_helper]
    @simulated_actual_org = org_context[:simulated_actual_org]
    
    # Impersonation Status
    impersonation = health_data[:impersonation_status]
    @is_impersonating = impersonation[:is_impersonating]
    @impersonating_teammate_id = impersonation[:impersonating_teammate_id]
    @impersonating_teammate = impersonation[:impersonating_teammate]
    @current_teammate = impersonation[:current_teammate]
    @impersonating_teammate_record = impersonation[:impersonating_teammate_record]
    @session_teammate_record = impersonation[:session_teammate_record]
    
    # Teammate Details
    teammate_details = health_data[:teammate_details]
    @current_teammate_id = teammate_details[:current_teammate_id]
    @current_teammate_type = teammate_details[:current_teammate_type]
    @current_teammate_org = teammate_details[:current_teammate_org]
    @current_teammate_permissions = teammate_details[:current_teammate_permissions]
    @current_person = teammate_details[:current_person]
    @all_teammates = teammate_details[:all_teammates]
    @session_teammate_id = teammate_details[:session_teammate_id]
    
    # Pundit User Structure
    pundit_user = health_data[:pundit_user_structure]
    @pundit_user_struct = pundit_user[:pundit_user_struct]
    @pundit_user_user = pundit_user[:pundit_user_user]
    @pundit_user_real_user = pundit_user[:pundit_user_real_user]
    
    # Managerial Hierarchy
    hierarchy = health_data[:managerial_hierarchy]
    @managers = hierarchy[:managers]
    @direct_reports = hierarchy[:direct_reports]
    
    # Policy Checks
    @policy_checks = health_data[:policy_checks]
    
    # Caching Information
    caching = health_data[:caching_information]
    @teammate_cached = caching[:teammate_cached]
    @cache_config = caching[:cache_config]
    
    # Session Data
    @session_data = health_data[:session_data]
  end
  
    private

  # Skip organization setup for actions that don't need it
  def skip_organization_setup?
    !%w[show edit update destroy switch huddles_review dashboard celebrate_milestones pundit_healthcheck accountability_chart refresh_slack_profiles].include?(action_name)
  end
  
  def organization_params
    params.require(:organization).permit(:name, :type, :parent_id)
  end
  
  def require_authentication
    unless current_company_teammate
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
      access_people = @organization.teammates.includes(:person)
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
      @total_seats = @organization.seats.count + @organization.children.sum { |child| child.seats.count }
      
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
  
  def load_organization_dashboard_stats
    # For now, we'll load basic stats - this will be expanded with the 9 pillar boxes
    if @organization.company?
      @total_employees = @organization.employees.count
      @total_teams = @organization.children.teams.count
      @total_departments = @organization.children.departments.count
      
      # Recent huddles for this organization
      @recent_org_huddles = @organization.huddles.recent.limit(3)
      
      # Basic pillar stats (will be expanded)
      @total_positions = @organization.positions.count + @organization.children.sum { |child| child.positions.count }
      @total_assignments = @organization.assignments.count + @organization.children.sum { |child| child.assignments.count }
      @total_abilities = @organization.abilities.count
      
      # Observation statistics for dashboard
      load_observation_dashboard_stats
    end
  end
  
  def load_observation_dashboard_stats
    # Get all observations for this organization (not soft deleted)
    all_observations = @organization.observations.where(deleted_at: nil)
    
    # Recent observations (this week)
    @recent_observations_count = all_observations.where(observed_at: 1.week.ago..).count
    
    # Journal entries (private observations)
    @journal_observations_count = all_observations.where(privacy_level: :observer_only).count
    
    # Public observations
    @public_observations_count = all_observations.where(privacy_level: :public_observation).count
    
    # Observations with ratings
    @observations_with_ratings_count = all_observations.joins(:observation_ratings).distinct.count
    
    # Observations posted to Slack
    @observations_posted_to_slack_count = all_observations.joins(:notifications).where(notifications: { status: 'sent_successfully' }).distinct.count
  end
  
  def load_check_ins_dashboard_stats
    # Use current teammate if it's in this organization, otherwise find teammate for this organization
    teammate = if current_company_teammate.organization == @organization || 
                  current_company_teammate.organization.root_company == @organization.root_company
      current_company_teammate
    else
      current_company_teammate.person.teammates.find_by(organization: @organization)
    end
    
    if teammate
      # Check for check-ins ready for finalization (manager perspective)
      position_ready = PositionCheckIn.where(teammate: teammate).ready_for_finalization.exists?
      assignment_ready = AssignmentCheckIn.where(teammate: teammate).ready_for_finalization.exists?
      aspiration_ready = AspirationCheckIn.where(teammate: teammate).ready_for_finalization.exists?
      @ready_for_finalization_count = [position_ready, assignment_ready, aspiration_ready].count(true)
      
      # Check for finalized check-in awaiting acknowledgement (employee perspective)
      # Find latest closed check-in within last 7 days that may need acknowledgement
      @finalized_check_in_exists = PositionCheckIn.where(teammate: teammate)
                                                   .closed
                                                   .where('official_check_in_completed_at > ?', 7.days.ago)
                                                   .exists? ||
                                  AssignmentCheckIn.where(teammate: teammate)
                                                   .closed
                                                   .where('official_check_in_completed_at > ?', 7.days.ago)
                                                   .exists? ||
                                  AspirationCheckIn.where(teammate: teammate)
                                                  .closed
                                                  .where('official_check_in_completed_at > ?', 7.days.ago)
                                                  .exists?
    else
      @ready_for_finalization_count = 0
      @finalized_check_in_exists = false
    end
  end
end
