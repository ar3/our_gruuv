class PeopleController < ApplicationController
  before_action :require_login
  before_action :set_person

  def show
    authorize @person
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
    @person = current_person
  end

  def person_params
    params.require(:person).permit(:first_name, :last_name, :middle_name, :suffix, 
                                  :email, :unique_textable_phone_number, :timezone)
  end
end 