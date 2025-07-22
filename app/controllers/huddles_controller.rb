class HuddlesController < ApplicationController
  before_action :set_huddle, only: [:show, :feedback, :submit_feedback, :join, :join_huddle, :summary]

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
    
    # Check if current user has already submitted feedback
    @existing_feedback = @huddle.huddle_feedbacks.find_by(person: current_person)
  end

  def summary
    authorize @huddle, :summary?
    # Check if user is a participant
    @current_person = current_person
    
    @existing_participant = @current_person.huddle_participants.find_by(huddle: @huddle)
    @huddle = @huddle.decorate
  end

  def new
    @huddle = Huddle.new
    @current_person = current_person
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
      expires_at: 24.hours.from_now,
      huddle_alias: huddle_params[:huddle_alias]
    )
    
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
      # Check if this is a duplicate huddle error
      if @huddle.errors[:existing_huddle_id].any?
        existing_huddle_id = @huddle.errors[:existing_huddle_id].first
        existing_huddle = Huddle.find(existing_huddle_id)
        
        # Add the person as a participant to the existing huddle
        existing_huddle.huddle_participants.find_or_create_by!(person: person) do |participant|
          participant.role = 'active' # Default role for joiners
        end
        
        # Store only the person ID in session
        session[:current_person_id] = person.id
        
        redirect_to existing_huddle, notice: "You've joined the existing huddle for today!"
      else
        render :new, status: :unprocessable_entity
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    @huddle = Huddle.new(huddle_params.except(:company_name, :team_name, :name, :email))
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
    capture_error_in_sentry(e, {
      method: 'join_huddle',
      huddle_id: @huddle.id,
      validation_errors: e.record.errors.full_messages
    })
    Rails.logger.error "🎯 JOIN_HUDDLE: RecordInvalid error: #{e.message}"
    Rails.logger.error "🎯 JOIN_HUDDLE: Errors: #{e.record.errors.full_messages}"
    render :join, status: :unprocessable_entity
  rescue => e
    capture_error_in_sentry(e, {
      method: 'join_huddle',
      huddle_id: @huddle.id
    })
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
      redirect_to @huddle, notice: 'Thank you for your feedback!'
    else
      render :feedback, status: :unprocessable_entity
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

  private

  def set_huddle
    @huddle = Huddle.find(params[:id])
  rescue ActiveRecord::RecordNotFound => e
    capture_error_in_sentry(e, {
      method: 'set_huddle',
      huddle_id: params[:id]
    })
    raise e
  end

  # Remove this method since it's already defined in ApplicationController

  def huddle_params
    params.require(:huddle).permit(:company_name, :team_name, :huddle_alias, :name, :email)
  end

  def find_or_create_organization
    company_name = huddle_params[:company_name]
    team_name = huddle_params[:team_name]
    
    # Guard against empty company name
    if company_name.blank?
      error = ActiveRecord::RecordInvalid.new(Company.new)
      capture_error_in_sentry(error, {
        method: 'find_or_create_organization',
        validation_error: 'company_name_blank'
      })
      raise error
    end
    
    # Find or create the company
    company = Company.find_or_create_by!(name: company_name)
    
    if team_name.present?
      # Find or create the team under this company
      Team.find_or_create_by!(name: team_name, parent: company)
    else
      company
    end
  rescue => e
    capture_error_in_sentry(e, {
      method: 'find_or_create_organization',
      company_name: company_name,
      team_name: team_name
    })
    raise e
  end

  # These methods are now abstracted to ApplicationController

  def join_params
    params.permit(:name, :email, :timezone, :role, :authenticity_token, :commit, :id)
  end

  def feedback_params
    params.permit(:informed_rating, :connected_rating, :goals_rating, :valuable_rating, 
                  :personal_conflict_style, :team_conflict_style,
                  :appreciation, :change_suggestion, :private_department_head, :private_facilitator, :anonymous)
  end
end
