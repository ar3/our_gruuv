class HuddlesController < ApplicationController
  before_action :set_huddle, only: [:show, :feedback, :submit_feedback]

  def index
    @huddles = Huddle.active.recent.includes(:organization)
  end

  def show
    # Show huddle details and the three sections
  end

  def new
    @huddle = Huddle.new
  end

  def create
    # Find or create the organization
    organization = find_or_create_organization
    
    # Find or create the person
    person = find_or_create_person
    
    # Create the huddle
    @huddle = Huddle.new(
      organization: organization,
      started_at: Time.current,
      huddle_alias: huddle_params[:alias]
    )
    
    if @huddle.save
      # Add the creator as a participant (default to facilitator)
      @huddle.huddle_participants.create!(
        person: person,
        role: 'facilitator'
      )
      
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

  def feedback
    # Show the feedback form
  end

  def submit_feedback
    # Handle feedback submission
    # This will be implemented in the next iteration
  end

  private

  def set_huddle
    @huddle = Huddle.find(params[:id])
  end

  def huddle_params
    params.require(:huddle).permit(:company_name, :team_name, :alias, :name, :email)
  end

  def find_or_create_organization
    company_name = huddle_params[:company_name]
    team_name = huddle_params[:team_name]
    
    # Guard against empty company name
    raise ActiveRecord::RecordInvalid.new(Company.new) if company_name.blank?
    
    # Find or create the company
    company = Company.find_or_create_by!(name: company_name)
    
    if team_name.present?
      # Find or create the team under this company
      Team.find_or_create_by!(name: team_name, parent: company)
    else
      company
    end
  end

  def find_or_create_person
    Person.find_or_create_by!(email: huddle_params[:email]) do |person|
      person.full_name = huddle_params[:name]
    end
  end
end
