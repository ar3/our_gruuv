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
  rescue => e
    capture_error_in_sentry(e, {
      method: 'update_profile',
      person_id: @person&.id
    })
    raise e
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