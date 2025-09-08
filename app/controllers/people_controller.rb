class PeopleController < ApplicationController
  layout 'authenticated-v2-0', only: [:show, :public, :teammate, :growth]
  before_action :require_login, except: [:public]
  before_action :set_person, except: [:index]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index
  
  helper_method :real_current_person

  def index
    authorize Person
    @people = policy_scope(Person).includes(:employment_tenures, :huddles)
                    .order(:first_name, :last_name)
                    .decorate
  end

  def show
    authorize @person
    @employment_tenures = @person.employment_tenures.includes(:company, :position, :manager)
                                 .order(started_at: :desc)
                                 .decorate
    @assignment_tenures = @person.assignment_tenures.includes(:assignment)
                                 .order(started_at: :desc)
    @person_organization_accesses = @person.person_organization_accesses.includes(:organization)
    
    # Preload huddle associations to avoid N+1 queries
    @person.huddle_participants.includes(:huddle, huddle: :huddle_playbook).load
    @person.huddle_feedbacks.includes(:huddle).load
  end

  def public
    authorize @person
    # Public view - minimal data, no sensitive information
    @employment_tenures = @person.employment_tenures.includes(:company)
                                 .order(started_at: :desc)
                                 .decorate
  end

  def teammate
    authorize @person
    # Teammate view - organization-specific data for active employees
    @current_organization = current_person&.current_organization
    @employment_tenures = @person.employment_tenures.includes(:company, :position, position: :position_type)
                                 .order(started_at: :desc)
                                 .decorate
    @person_organization_accesses = @person.person_organization_accesses.includes(:organization)
  end

  def growth
    authorize @person, :manager?
    # Growth view - detailed view for managers to see person's position, assignments, and milestones
    @employment_tenures = @person.employment_tenures.includes(:company, :position, :manager)
                                 .order(started_at: :desc)
                                 .decorate
    @current_employment = @employment_tenures.find { |t| t.ended_at.nil? }
    @current_organization = @current_employment&.company
  end



  def edit
    authorize @person
  end

  def update
    authorize @person
    if @person.update(person_params)
      redirect_to profile_path, notice: 'Profile updated successfully!'
    else
      capture_error_in_sentry(ActiveRecord::RecordInvalid.new(@person), {
        method: 'update_profile',
        person_id: @person.id,
        validation_errors: @person.errors.full_messages
      })
      render :edit, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique => e
    # Handle unique constraint violations (like duplicate phone numbers)
    capture_error_in_sentry(e, {
      method: 'update_profile',
      person_id: @person&.id,
      error_type: 'unique_constraint_violation'
    })
    @person.errors.add(:unique_textable_phone_number, 'is already taken by another user')
    render :edit, status: :unprocessable_entity
  rescue ActiveRecord::StatementInvalid => e
    # Handle other database constraint violations
    capture_error_in_sentry(e, {
      method: 'update_profile',
      person_id: @person&.id,
      error_type: 'database_constraint_violation'
    })
    @person.errors.add(:base, 'Unable to update profile due to a database constraint. Please try again.')
    render :edit, status: :unprocessable_entity
  rescue => e
    capture_error_in_sentry(e, {
      method: 'update_profile',
      person_id: @person&.id
    })
    @person.errors.add(:base, 'An unexpected error occurred while updating your profile. Please try again.')
    render :edit, status: :unprocessable_entity
  end

  def connect_google_identity
    authorize @person
    redirect_to "/auth/google_oauth2", data: { turbo: false }
  end

  def disconnect_identity
    authorize @person
    identity = @person.person_identities.find(params[:id])
    
    unless @person.can_disconnect_identity?(identity)
      redirect_to profile_path, alert: 'Cannot disconnect this account. Please add another Google account first.'
      return
    end
    
    if identity.destroy
      redirect_to profile_path, notice: 'Account disconnected successfully!'
    else
      redirect_to profile_path, alert: 'Failed to disconnect account. Please try again.'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to profile_path, alert: 'Account not found.'
  end

  private

  def require_login
    unless current_person
      redirect_to root_path, alert: 'Please log in to access your profile'
    end
  end

  def set_person
    # If params[:id] is present, find that person; otherwise use current_person
    if params[:id].present?
      @person = Person.find(params[:id])
    else
      @person = current_person
    end
    
    # Always set @current_person for the view
    @current_person = current_person
  end



  def person_params
    params.require(:person).permit(:first_name, :last_name, :middle_name, :suffix, 
                                  :email, :unique_textable_phone_number, :timezone)
  end
end 