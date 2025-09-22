class ImpersonationsController < ApplicationController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :ensure_admin!

  def create
    person = Person.find(params[:person_id])
    
    if start_impersonation(person)
      flash[:notice] = "Now impersonating #{person.display_name}"
      redirect_back(fallback_location: root_path)
    else
      flash[:error] = "Unable to impersonate #{person.display_name}"
      redirect_back(fallback_location: root_path)
    end
  end

  def destroy
    Rails.logger.info "IMPERSONATION_DESTROY: 1 - Impersonation destroy called"
    Rails.logger.info "IMPERSONATION_DESTROY: 2 - Current person: #{current_person&.id} (#{current_person&.full_name})"
    Rails.logger.info "IMPERSONATION_DESTROY: 3 - Real person: #{real_current_person&.id} (#{real_current_person&.full_name})"
    Rails.logger.info "IMPERSONATION_DESTROY: 4 - Referer: #{request.referer}"
    Rails.logger.info "IMPERSONATION_DESTROY: 5 - User agent: #{request.user_agent}"
    Rails.logger.info "IMPERSONATION_DESTROY: 6 - Request method: #{request.method}"
    Rails.logger.info "IMPERSONATION_DESTROY: 7 - Request path: #{request.path}"
    
    stop_impersonation
    flash[:notice] = "Stopped impersonation"
    redirect_back(fallback_location: root_path)
  end

  private

  def authenticate_person!
    unless current_person
      flash[:error] = "You must be logged in to impersonate someone"
      redirect_to root_path
    end
  end

  def ensure_admin!
    unless real_current_person
      flash[:error] = "You must be logged in to impersonate someone"
      redirect_to root_path
      return
    end
    
    # Use Pundit policy for authorization
    policy = PersonPolicy.new(real_current_person, nil)
    unless policy.can_impersonate_anyone?
      flash[:error] = "Only administrators can impersonate users"
      redirect_to root_path
    end
  end
end
