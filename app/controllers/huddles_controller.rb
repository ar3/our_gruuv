class HuddlesController < ApplicationController
  before_action :set_huddle, only: [:show, :feedback, :submit_feedback, :join, :join_huddle, :direct_feedback, :post_start_announcement_to_slack, :notifications_debug]
  before_action :authenticate_person!, only: [:new]

  def index
    @huddles = Huddle.active.recent.includes(team: :company).decorate
    @huddles_by_company = @huddles.group_by { |huddle| huddle.company&.root_company }.sort_by { |company, _| company&.name || '' }

    # Get teams with recent huddles for the current organization
    if current_organization
      @recent_teams = current_organization.teams_with_recent_huddles

      # Get weekly summary status for the current organization
      @weekly_summary_status = get_weekly_summary_status(current_organization)

      # Get active huddles for each team to show current status
      @team_active_huddles = get_team_active_huddles(@recent_teams)
    end
  end

  def my_huddles
    @current_person = current_person

    if @current_person
      @huddles = Huddle.participated_by(@current_person).recent.includes(team: :company)
      @huddles_by_company = @huddles.group_by { |huddle| huddle.company&.root_company }.sort_by { |company, _| company&.name || '' }
    else
      redirect_to huddles_path, alert: "Please log in to view your huddles"
    end
  end

  def show
    authorize @huddle

    # If user is not logged in, redirect to join page
    unless current_person
      redirect_to join_huddle_path(@huddle)
      return
    end

    # Check if user is a participant, if not redirect to join page
    @existing_participant = HuddleParticipant.joins(:company_teammate).find_by(huddle: @huddle, teammates: { person: current_person })
    unless @existing_participant
      redirect_to join_huddle_path(@huddle)
      return
    end

    # Check if current user has already submitted feedback
    @existing_feedback = @huddle.huddle_feedbacks.joins(:company_teammate).find_by(teammates: { person: current_person })

    # Set up variables for the Evolve section
    @current_person = current_person
    @is_facilitator = @existing_participant&.facilitator? || @huddle.company&.department_head == @current_person
  end



  def new
    @huddle = Huddle.new
    @current_person = current_person

    # Get all teams from all companies the current person is a part of
    # Group teams by company for display
    @teams_by_company = {}
    
    current_person.active_teammates
                  .includes(organization: :teams)
                  .each do |teammate|
      company = teammate.organization
      next unless company

      teams = company.teams.active.ordered
      @teams_by_company[company] = teams if teams.any?
    end
    
    # Sort companies by name
    @teams_by_company = @teams_by_company.sort_by { |company, _| company.name }.to_h
  end

  def create
    # Find or create the team
    team = find_or_create_team

    # Get the person - either from session or create from params
    person = get_or_create_person_from_session_or_params

    # Check if there's already an active huddle for this team this week
    this_week_start = Time.current.beginning_of_week(:monday)
    this_week_end = Time.current.end_of_week(:sunday)

    existing_huddle = Huddle.where(team: team)
                           .where(started_at: this_week_start..this_week_end)
                           .where('expires_at > ?', Time.current)
                           .order(started_at: :desc)
                           .first

    if existing_huddle
      # Add the creator as a participant to the existing huddle
      teammate = person.teammates.find_by(organization: existing_huddle.company)
      participant = existing_huddle.huddle_participants.find_or_create_by!(teammate: teammate) do |p|
        p.role = 'facilitator'
      end

      # Store only the person ID in session
      session[:current_person_id] = person.id

      # Redirect to the existing huddle with a notice
      redirect_to huddle_path(existing_huddle), notice: 'A huddle for this team is already active this week. You have been added as a participant!'
      return
    end

    # Create the huddle
    @huddle = Huddle.new(
      team: team,
      started_at: Time.current,
      expires_at: 24.hours.from_now
    )

    authorize @huddle

    if @huddle.save
      # Find teammate for this person and company
      teammate = person.teammates.find_by(organization: @huddle.company)

      # Create teammate if it doesn't exist
      unless teammate
        teammate = person.teammates.create!(organization: @huddle.company, type: 'CompanyTeammate')
      end

      # Add the creator as a participant (default to facilitator)
      @huddle.huddle_participants.create!(
        teammate: teammate,
        role: 'facilitator'
      )

      # Store only the person ID in session
      session[:current_person_id] = person.id

      # Post announcements to Slack immediately (if configured)
      Huddles::PostAnnouncementJob.perform_and_get_result(@huddle.id)
      Huddles::PostSummaryJob.perform_and_get_result(@huddle.id)

      # Run weekly summary job when huddle is created
      if @huddle.company&.root_company
        Companies::WeeklyHuddlesReviewNotificationJob.perform_later(@huddle.company.root_company.id)
      end

      redirect_to @huddle, notice: 'Huddle created successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    @huddle = Huddle.new(huddle_params.except(:company_selection, :new_company_name, :team_name, :email))
    @huddle.errors.merge!(e.record.errors)
    render :new, status: :unprocessable_entity
  end


  # Get person from session or create from params
  def get_or_create_person_from_session_or_params(params_key = :huddle)
    if session[:current_person_id]
      Person.find(session[:current_person_id])
    else
      find_or_create_person_from_params(params_key)
    end
  rescue ActiveRecord::RecordNotFound => e
    capture_error_in_sentry(e, {
      method: 'get_or_create_person_from_session_or_params',
      session_person_id: session[:current_person_id],
      params_key: params_key
    })
    Rails.logger.error "GET_OR_CREATE_PERSON: Person not found in session: #{session[:current_person_id]}"
    Rails.logger.error "GET_OR_CREATE_PERSON: Clearing session and creating from params"
    session.delete(:current_person_id)
    find_or_create_person_from_params(params_key)
  rescue => e
    capture_error_in_sentry(e, {
      method: 'get_or_create_person_from_session_or_params',
      session_person_id: session[:current_person_id],
      params_key: params_key
    })
    Rails.logger.error "GET_OR_CREATE_PERSON: Error creating person from params: #{e.class} - #{e.message}"
    Rails.logger.error "GET_OR_CREATE_PERSON: Backtrace: #{e.backtrace.first(5).join("\n")}"
    raise e
  end

  # Find or create person from specific params
  def find_or_create_person_from_params(params_key = :huddle)
    begin
      # For join params, they're at the top level, not nested
      if params_key == :join
        email = params[:email]
        name = params[:name]
        timezone = params[:timezone]
      else
        params_obj = params[params_key]
        email = params_obj[:email]
        name = params_obj[:name]
        timezone = params_obj[:timezone]
      end

      # Validate required fields
      if email.blank?
        error = ActiveRecord::RecordInvalid.new(Person.new)
        capture_error_in_sentry(error, {
          method: 'find_or_create_person_from_params',
          params_key: params_key,
          validation_error: 'email_blank'
        })
        Rails.logger.error "FIND_OR_CREATE_PERSON_FROM_PARAMS: Email is blank!"
        raise error, "Email is required"
      end

      # Auto-generate name from email if not provided and person doesn't exist
      if name.blank?
        existing_person = Person.find_by(email: email)
        if existing_person&.full_name.present?
          name = existing_person.full_name
        else
          name = email.split('@').first.gsub('.', ' ').titleize
        end
      end

      # If no timezone provided, try to detect from request
      timezone ||= detect_timezone_from_request

      # Find or create the person
      person = Person.find_or_create_by!(email: email) do |p|
        p.full_name = name
        p.safe_timezone = timezone if timezone.present?
      end

      # Update the name and timezone if they changed
      updates = {}
      updates[:full_name] = name if person.full_name != name

      # Use safe timezone assignment for updates
      if timezone.present? && person.timezone != timezone
        person.safe_timezone = timezone
        updates[:timezone] = person.timezone
      end

      person.update!(updates) if updates.any?

      person
    rescue ActiveRecord::RecordInvalid => e
      capture_error_in_sentry(e, {
        method: 'find_or_create_person_from_params',
        params_key: params_key,
        validation_errors: e.record.errors.full_messages
      })
      Rails.logger.error "FIND_OR_CREATE_PERSON_FROM_PARAMS: RecordInvalid error: #{e.message}"
      Rails.logger.error "FIND_OR_CREATE_PERSON_FROM_PARAMS: Errors: #{e.record.errors.full_messages}"
      raise e
    rescue => e
      capture_error_in_sentry(e, {
        method: 'find_or_create_person_from_params',
        params_key: params_key
      })
      Rails.logger.error "FIND_OR_CREATE_PERSON_FROM_PARAMS: Unexpected error: #{e.class} - #{e.message}"
      Rails.logger.error "FIND_OR_CREATE_PERSON_FROM_PARAMS: Backtrace: #{e.backtrace.first(5).join("\n")}"
      raise e
    end
  end

  def join
    authorize @huddle, :join?
    # Set current person from session
    @current_person = current_person

    # Set existing participant if user is logged in
    @existing_participant = HuddleParticipant.joins(:company_teammate).find_by(huddle: @huddle, teammates: { person: @current_person }) if @current_person

    # Store return path for post-auth redirect
    if @current_person.nil?
      session[:return_to] = join_huddle_path(@huddle)
    end
  end

  def join_huddle
    authorize @huddle, :join_huddle?

    # Require authentication
    unless current_person
      redirect_to join_huddle_path(@huddle), alert: 'Please sign in to join this huddle.'
      return
    end

    # Find or create teammate for this person and company
    teammate = current_person.teammates.find_by(organization: @huddle.company)

    # Create follower teammate if it doesn't exist
    unless teammate
      teammate = current_person.teammates.create!(
        organization: @huddle.company,
        type: 'CompanyTeammate'
        # No employment dates = follower status
      )
    end

    # Add or update the person as a participant to the huddle
    participant = @huddle.huddle_participants.find_or_create_by!(teammate: teammate) do |p|
      p.role = join_params[:role]
    end

    # Update teammate if it changed
    if participant.teammate != teammate
      participant.update!(teammate: teammate)
    end

    # Update role if it changed
    role_changed = participant.role != join_params[:role]
    participant.update!(role: join_params[:role]) if role_changed

    # Store only the person ID in session
    session[:current_person_id] = current_person.id

    # Run required jobs when someone joins
    if @huddle.company&.root_company
      Companies::WeeklyHuddlesReviewNotificationJob.perform_later(@huddle.company.root_company.id)
    end
    Huddles::PostAnnouncementJob.perform_and_get_result(@huddle.id)
    Huddles::PostSummaryJob.perform_and_get_result(@huddle.id)

    if role_changed
      redirect_to @huddle, notice: "Role updated successfully!"
    else
      redirect_to @huddle, notice: "Welcome to the huddle!"
    end
  rescue ActiveRecord::RecordInvalid => e
    capture_error_in_sentry(e, {
      method: 'join_huddle',
      huddle_id: @huddle.id,
      validation_errors: e.record.errors.full_messages
    })
    Rails.logger.error "JOIN_HUDDLE: RecordInvalid error: #{e.message}"
    Rails.logger.error "JOIN_HUDDLE: Errors: #{e.record.errors.full_messages}"
    render :join, status: :unprocessable_entity
  rescue => e
    capture_error_in_sentry(e, {
      method: 'join_huddle',
      huddle_id: @huddle.id
    })
    Rails.logger.error "JOIN_HUDDLE: Unexpected error: #{e.class} - #{e.message}"
    Rails.logger.error "JOIN_HUDDLE: Backtrace: #{e.backtrace.first(5).join("\n")}"
    raise e
  end

  def direct_feedback
    # Require authentication first, before authorization
    unless current_person
      session[:return_to] = direct_feedback_huddle_path(@huddle)
      redirect_to '/auth/google_oauth2', alert: 'Please sign in to give feedback.'
      return
    end

    authorize @huddle, :direct_feedback?

    # Check if user is already a participant
    @existing_participant = HuddleParticipant.joins(:company_teammate).find_by(huddle: @huddle, teammates: { person: current_person })

    unless @existing_participant
      # Find or create follower teammate for this person and company
      teammate = current_person.teammates.find_by(organization: @huddle.company)

      # Create follower teammate if it doesn't exist
      unless teammate
        teammate = current_person.teammates.create!(
          organization: @huddle.company,
          type: 'CompanyTeammate'
          # No employment dates = follower status
        )
      end

      # Auto-create participant with role "active"
      @existing_participant = @huddle.huddle_participants.create!(
        teammate: teammate,
        role: 'active'
      )

      flash[:notice] = "You've been added to the huddle. Please share your feedback!"
    end

    # Redirect to regular feedback page
    redirect_to feedback_huddle_path(@huddle)
  end

  def feedback
    authorize @huddle, :feedback?
    # Get current person from session
    @current_person = current_person

    # Check if user is a participant
    @existing_participant = HuddleParticipant.joins(:company_teammate).find_by(huddle: @huddle, teammates: { person: @current_person })

    # Check if user has already submitted feedback
    @existing_feedback = @huddle.huddle_feedbacks.joins(:company_teammate).find_by(teammates: { person: @current_person })

    # Check if this is first time giving feedback
    @is_first_time_feedback = @current_person.total_feedback_given == 0
  end

  def submit_feedback
    authorize @huddle, :submit_feedback?
    # Get the current person from session
    @current_person = current_person

    # Check if user is a participant
    @existing_participant = HuddleParticipant.joins(:company_teammate).find_by(huddle: @huddle, teammates: { person: @current_person })

    # Check if user has already submitted feedback
    @existing_feedback = @huddle.huddle_feedbacks.joins(:company_teammate).find_by(teammates: { person: @current_person })

    if @existing_feedback
      # Update existing feedback
      if @existing_feedback.update(
        informed_rating: feedback_params[:informed_rating],
        connected_rating: feedback_params[:connected_rating],
        goals_rating: feedback_params[:goals_rating],
        valuable_rating: feedback_params[:valuable_rating],
        personal_conflict_style: feedback_params[:personal_conflict_style],
        team_conflict_style: feedback_params[:team_conflict_style],
        appreciation: feedback_params[:appreciation],
        change_suggestion: feedback_params[:change_suggestion],
        private_department_head: feedback_params[:private_department_head],
        private_facilitator: feedback_params[:private_facilitator],
        anonymous: feedback_params[:anonymous] == '1'
      )
        # Update announcement and summary (but don't post new feedback notification)
        Huddles::PostAnnouncementJob.perform_and_get_result(@huddle.id)
        Huddles::PostSummaryJob.perform_and_get_result(@huddle.id)

        # Run weekly summary job when feedback is updated
        if @huddle.company&.root_company
          Companies::WeeklyHuddlesReviewNotificationJob.perform_later(@huddle.company.root_company.id)
        end

        redirect_to @huddle, notice: 'Your feedback has been updated!'
      else
        @feedback = @existing_feedback
        render :feedback, status: :unprocessable_entity
      end
    else
      # Find teammate for this person and company
      teammate = @current_person.teammates.find_by(organization: @huddle.company)

      # Create new feedback
      @feedback = @huddle.huddle_feedbacks.build(
        teammate: teammate,
        informed_rating: feedback_params[:informed_rating],
        connected_rating: feedback_params[:connected_rating],
        goals_rating: feedback_params[:goals_rating],
        valuable_rating: feedback_params[:valuable_rating],
        personal_conflict_style: feedback_params[:personal_conflict_style],
        team_conflict_style: feedback_params[:team_conflict_style],
        appreciation: feedback_params[:appreciation],
        change_suggestion: feedback_params[:change_suggestion],
        private_department_head: feedback_params[:private_department_head],
        private_facilitator: feedback_params[:private_facilitator],
        anonymous: feedback_params[:anonymous] == '1'
      )

      if @feedback.save
        # Update summary and post feedback
        Huddles::PostAnnouncementJob.perform_and_get_result(@huddle.id)
        Huddles::PostSummaryJob.perform_and_get_result(@huddle.id)
        Huddles::PostFeedbackJob.perform_and_get_result(@huddle.id, @feedback.id)

        # Run weekly summary job when feedback is completed
        if @huddle.company&.root_company
          Companies::WeeklyHuddlesReviewNotificationJob.perform_later(@huddle.company.root_company.id)
        end

        redirect_to @huddle, notice: 'Thank you for your feedback!'
      else
        render :feedback, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    capture_error_in_sentry(e, {
      method: 'submit_feedback',
      huddle_id: @huddle.id,
      validation_errors: e.record.errors.full_messages
    })
    @feedback = @huddle.huddle_feedbacks.build(feedback_params)
    @feedback.errors.merge!(e.record.errors)
    render :feedback, status: :unprocessable_entity
  end





  def post_start_announcement_to_slack
    authorize @huddle, :show?

    unless @huddle.slack_configured?
      redirect_to huddle_path(@huddle), alert: 'Slack huddle channel is not configured for this team.'
      return
    end

    begin
      # Post the start announcement to Slack using the job
      Huddles::PostAnnouncementJob.perform_and_get_result(@huddle.id)

      redirect_to huddle_path(@huddle), notice: 'Huddle start announcement posted to Slack successfully!'
    rescue => e
      redirect_to huddle_path(@huddle), alert: "Failed to post to Slack: #{e.message}"
    end
  end

  def notifications_debug
    authorize @huddle, :show?
    @notifications = @huddle.notifications.order(created_at: :desc)
  end

  def start_huddle_from_team
    team = Team.find_by(id: params[:team_id])
    unless team
      flash[:alert] = "Team not found"
      redirect_to huddles_path and return
    end
    authorize team, :show?

    # Check if there's already an active huddle for this team this week
    this_week_start = Time.current.beginning_of_week(:monday)
    this_week_end = Time.current.end_of_week(:sunday)

    existing_huddle = Huddle.where(team: team)
                           .where(started_at: this_week_start..this_week_end)
                           .where('expires_at > ?', Time.current)
                           .order(started_at: :desc)
                           .first

    if existing_huddle
      # Add the current user as a participant to the existing huddle
      person = current_person
      if person
        teammate = person.teammates.find_by(organization: team.company)
        participant = existing_huddle.huddle_participants.find_or_create_by!(teammate: teammate) do |p|
          p.role = 'active'
        end

        # Store the person ID in session
        session[:current_person_id] = person.id

        # Redirect to the existing huddle with a notice
        redirect_to huddle_path(existing_huddle), notice: 'A huddle for this team is already active this week. You have been added as a participant!'
      else
        # If no current person, redirect to join the existing huddle
        redirect_to join_huddle_path(existing_huddle), notice: 'A huddle for this team is already active this week. Please join the existing huddle.'
      end
      return
    end

    # Create a new huddle for this team
    @huddle = Huddle.new(
      team: team,
      started_at: Time.current,
      expires_at: 24.hours.from_now
    )

    if @huddle.save
      # Post announcements to Slack (if configured)
      Huddles::PostAnnouncementJob.perform_and_get_result(@huddle.id)
      Huddles::PostSummaryJob.perform_and_get_result(@huddle.id)

      # Run weekly summary job when huddle is created
      if @huddle.company&.root_company
        Companies::WeeklyHuddlesReviewNotificationJob.perform_later(@huddle.company.root_company.id)
      end

      redirect_to huddles_path, notice: 'Huddle started successfully!'
    else
      redirect_to huddles_path, alert: 'Failed to start huddle. Please try again.'
    end
  end

  def post_weekly_summary
    if current_organization&.root_company
      success = Companies::WeeklyHuddlesReviewNotificationJob.perform_and_get_result(current_organization.root_company.id)

      if success[:success]
        redirect_to huddles_path, notice: 'Weekly huddle summary posted to Slack successfully!'
      else
        redirect_to huddles_path, alert: "Failed to post weekly summary: #{success[:error]}"
      end
    else
      redirect_to huddles_path, alert: 'No company selected. Please select a company first.'
    end
  end

  private

  def set_huddle
    @huddle = Huddle.find(params[:id]).decorate
  rescue ActiveRecord::RecordNotFound => e
    capture_error_in_sentry(e, {
      method: 'set_huddle',
      huddle_id: params[:id]
    })
    raise e
  end

  def huddle_params
    params.require(:huddle).permit(:company_selection, :new_company_name, :team_selection, :new_team_name, :team_name, :email)
  end

  def find_or_create_team
    company_selection = huddle_params[:company_selection]
    new_company_name = huddle_params[:new_company_name]
    team_selection = huddle_params[:team_selection]
    new_team_name = huddle_params[:new_team_name]
    team_name = huddle_params[:team_name]

    # Determine the company name
    company_name = if company_selection == 'new'
      new_company_name
    else
      company_selection
    end

    # Guard against empty company name
    if company_name.blank?
      error = ActiveRecord::RecordInvalid.new(Organization.new)
      capture_error_in_sentry(error, {
        method: 'find_or_create_team',
        validation_error: 'company_name_blank'
      })
      raise error
    end

    # Find or create the organization
    company = Organization.find_or_create_by!(name: company_name)

    # Determine the team name
    final_team_name = if company_selection == 'new'
      # If creating a new company, use the new team name
      new_team_name
    elsif team_selection == 'new'
      # If existing company but new team selected
      new_team_name
    elsif team_selection.present?
      # If existing company and existing team selected
      team_selection
    else
      # Fallback to old parameter
      team_name
    end

    # Default to "General" team if no team specified
    final_team_name = 'General' if final_team_name.blank?

    # Find or create the team under this company
    Team.find_or_create_by!(name: final_team_name, company: company)
  rescue => e
    capture_error_in_sentry(e, {
      method: 'find_or_create_team',
      company_name: company_name,
      team_name: final_team_name
    })
    raise e
  end

  # These methods are now abstracted to ApplicationController

  def join_params
    params.permit(:email, :timezone, :role, :authenticity_token, :commit, :id)
  end

  def feedback_params
    params.permit(:informed_rating, :connected_rating, :goals_rating, :valuable_rating,
                  :appreciation, :change_suggestion, :team_conflict_style, :personal_conflict_style,
                  :private_department_head, :private_facilitator, :anonymous, :authenticity_token, :commit)
  end

  def get_weekly_summary_status(organization)
    # Check if there's a recent weekly summary for this organization
    # Look for the most recent successful weekly summary notification from this week
    week_start = Date.current.beginning_of_week(:monday)
    week_end = Date.current.end_of_week(:sunday)

    recent_summary = Notification.where(
      notifiable: organization.root_company,
      notification_type: 'huddle_summary',
      status: 'sent_successfully',
      created_at: week_start..week_end
    ).order(created_at: :desc).first

    if recent_summary
      {
        has_recent_summary: true,
        last_posted_at: recent_summary.created_at,
        slack_message_url: recent_summary.slack_url
      }
    else
      {
        has_recent_summary: false,
        last_posted_at: nil,
        slack_message_url: nil
      }
    end
  end

  def get_team_active_huddles(teams)
    # Get active huddles for each team, focusing on the most recent one for this week
    active_huddles = {}

    teams.each do |team|
      # Get the most recent active huddle for this team from this week
      this_week_start = Time.current.beginning_of_week(:monday)
      this_week_end = Time.current.end_of_week(:sunday)

      latest_huddle = Huddle.where(team: team)
                           .where(started_at: this_week_start..this_week_end)
                           .where('expires_at > ?', Time.current)
                           .order(started_at: :desc)
                           .first

      if latest_huddle
        # Check if current user has participated
        current_participant = latest_huddle.huddle_participants.joins(:company_teammate).find_by(teammates: { person: current_person })
        has_feedback = latest_huddle.huddle_feedbacks.joins(:company_teammate).exists?(teammates: { person: current_person })

        active_huddles[team.id] = {
          huddle: latest_huddle,
          participant: current_participant,
          has_feedback: has_feedback,
          slack_message_url: get_slack_message_url(latest_huddle)
        }
      end
    end

    active_huddles
  end

  def get_slack_message_url(huddle)
    # Get the Slack message URL for this huddle's announcement
    huddle.slack_announcement_url
  end

end
