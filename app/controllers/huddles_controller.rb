class HuddlesController < ApplicationController
  before_action :set_huddle, only: [:show, :feedback, :submit_feedback, :join, :join_huddle, :post_start_announcement_to_slack]

  def index
    @huddles = Huddle.active.recent.includes(:organization)
    @huddles_by_organization = @huddles.group_by { |huddle| huddle.organization.root_company }.sort_by { |company, _| company&.name || '' }
  end

  def my_huddles
    @current_person = current_person
    
    if @current_person
      @huddles = Huddle.participated_by(@current_person).recent.includes(:organization)
      @huddles_by_organization = @huddles.group_by { |huddle| huddle.organization.root_company }.sort_by { |company, _| company&.name || '' }
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
    @existing_participant = current_person.huddle_participants.find_by(huddle: @huddle)
    unless @existing_participant
      redirect_to join_huddle_path(@huddle)
      return
    end
    
    # Check if current user has already submitted feedback
    @existing_feedback = @huddle.huddle_feedbacks.find_by(person: current_person)
    
    # Set up variables for the Evolve section
    @current_person = current_person
    @is_facilitator = @existing_participant&.facilitator? || @huddle.organization&.department_head == @current_person
  end



  def new
    @huddle = Huddle.new
    @current_person = current_person
    
    # Pre-populate with last company and team if user has participated in huddles
    if @current_person
      last_company = @current_person.last_huddle_company
      last_team = @current_person.last_huddle_team
      
      if last_company
        @initial_company_selection = last_company.name
        if last_team
          @initial_team_selection = last_team.name
        end
      end
    end
  end

  def create
    # Find or create the organization
    organization = find_or_create_organization
    
    # Get the person - either from session or create from params
    person = get_or_create_person_from_session_or_params
    
    # Create the huddle
    @huddle = Huddle.new(
      organization: organization,
      started_at: Time.current,
      expires_at: 24.hours.from_now
    )
    
    # Find or create default huddle playbook
    huddle_playbook = find_or_create_huddle_instruction(organization)
    
    # Assign the playbook to the huddle
    @huddle.huddle_playbook = huddle_playbook
    
    authorize @huddle
    
    if @huddle.save
      # Add the creator as a participant (default to facilitator)
      @huddle.huddle_participants.create!(
        person: person,
        role: 'facilitator'
      )
      
      # Store only the person ID in session
      session[:current_person_id] = person.id
      
      redirect_to @huddle, notice: 'Huddle created successfully!'
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    @huddle = Huddle.new(huddle_params.except(:company_selection, :new_company_name, :team_name, :email))
    @huddle.errors.merge!(e.record.errors)
    render :new, status: :unprocessable_entity
  end

  def join
    authorize @huddle, :join?
    # Set current person from session
    @current_person = current_person
    
    # Set existing participant if user is logged in
    @existing_participant = @current_person&.huddle_participants&.find_by(huddle: @huddle)
  end

  def join_huddle
    authorize @huddle, :join_huddle?
    
    # Get the person - either from session or create from params
    person = get_or_create_person_from_session_or_params(:join)
    
    # Add or update the person as a participant to the huddle
    participant = @huddle.huddle_participants.find_or_create_by!(person: person) do |p|
      p.role = join_params[:role]
    end
    
    # Update role if it changed
    role_changed = participant.role != join_params[:role]
    participant.update!(role: join_params[:role]) if role_changed
    
    # Store only the person ID in session
    session[:current_person_id] = person.id
    
    if role_changed
      redirect_to @huddle, notice: "Role updated successfully!"
    else
      redirect_to @huddle, notice: "Welcome to the huddle!"
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "🎯 JOIN_HUDDLE: RecordInvalid error: #{e.message}"
    Rails.logger.error "🎯 JOIN_HUDDLE: Errors: #{e.record.errors.full_messages}"
    render :join, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "🎯 JOIN_HUDDLE: Unexpected error: #{e.class} - #{e.message}"
    Rails.logger.error "🎯 JOIN_HUDDLE: Backtrace: #{e.backtrace.first(5).join("\n")}"
    raise e
  end

  def feedback
    authorize @huddle, :feedback?
    # Get current person from session
    @current_person = current_person
    
    # Check if user is a participant
    @existing_participant = @current_person.huddle_participants.find_by(huddle: @huddle)
  end

  def submit_feedback
    authorize @huddle, :submit_feedback?
    # Get the current person from session
    @current_person = current_person
    
    # Check if user is a participant
    @existing_participant = @current_person.huddle_participants.find_by(huddle: @huddle)
    
    # Create the feedback
    @feedback = @huddle.huddle_feedbacks.build(
      person: @current_person,
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
      Huddles::PostSummaryJob.perform_now(@huddle.id)
      Huddles::PostFeedbackJob.perform_now(@huddle.id, @feedback.id)
      
      redirect_to @huddle, notice: 'Thank you for your feedback!'
    else
      render :feedback, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordInvalid => e
    @feedback = @huddle.huddle_feedbacks.build(feedback_params)
    @feedback.errors.merge!(e.record.errors)
    render :feedback, status: :unprocessable_entity
  end





  def post_start_announcement_to_slack
    authorize @huddle, :show?
    
    unless @huddle.slack_configured?
      redirect_to huddle_path(@huddle), alert: 'Slack is not configured for this organization.'
      return
    end
    
    begin
      # Post the start announcement to Slack using the job
      Huddles::PostAnnouncementJob.perform_now(@huddle.id)
      
      redirect_to huddle_path(@huddle), notice: 'Huddle start announcement posted to Slack successfully!'
    rescue => e
      redirect_to huddle_path(@huddle), alert: "Failed to post to Slack: #{e.message}"
    end
  end

  private

  def set_huddle
    @huddle = Huddle.find(params[:id]).decorate
  end

  # Remove this method since it's already defined in ApplicationController

  def huddle_params
    params.require(:huddle).permit(:company_selection, :new_company_name, :team_selection, :new_team_name, :team_name, :email)
  end

  def find_or_create_organization
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
      company = Company.new
      company.errors.add(:name, "can't be blank")
      raise ActiveRecord::RecordInvalid.new(company)
    end
    
    # Find or create the company
    company = Company.find_or_create_by!(name: company_name)
    
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
    
    if final_team_name.present?
      # Find or create the team under this company
      # If team with exact name exists, use it; otherwise create new one
      Team.find_or_create_by!(name: final_team_name, parent: company)
    else
      company
    end
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
  
  def find_or_create_huddle_instruction(organization)
    # Find existing default playbook for this organization
    playbook = organization.huddle_playbooks.find_by(special_session_name: nil)
    
    # If not found, create a new default one
    unless playbook
      playbook = organization.huddle_playbooks.create!(
        special_session_name: nil,
        slack_channel: nil # Use organization default
      )
    end
    
    playbook
  end
end
