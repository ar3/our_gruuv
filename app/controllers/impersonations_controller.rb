class ImpersonationsController < ApplicationController
  layout 'authenticated-v2-0'
  before_action :authenticate_person!
  before_action :ensure_admin!, except: [:destroy]
  before_action :ensure_impersonating!, only: [:destroy]

  def create
    # Accept either person_id or email parameter
    if params[:email].present?
      person = Person.find_by(email: params[:email])
      unless person
        flash[:error] = "No user found with email: #{params[:email]}"
        redirect_back(fallback_location: root_path)
        return
      end
    elsif params[:person_id].present?
      person = Person.find(params[:person_id])
    else
      flash[:error] = "Either person_id or email must be provided"
      redirect_back(fallback_location: root_path)
      return
    end
    
    # Find or create a teammate for the person (prefer active teammates)
    teammate = ensure_teammate_for_person(person)
    
    if start_impersonation(teammate)
      flash[:notice] = "Now impersonating #{person.display_name}"
      redirect_back(fallback_location: root_path)
    else
      flash[:error] = "Unable to impersonate #{person.display_name}"
      redirect_back(fallback_location: root_path)
    end
  end

  def destroy
    Rails.logger.info "IMPERSONATION_DESTROY: 1 - Impersonation destroy called"
    Rails.logger.info "IMPERSONATION_DESTROY: 2 - Current teammate: #{current_company_teammate&.id} (#{current_person&.full_name})"
    Rails.logger.info "IMPERSONATION_DESTROY: 3 - Impersonating teammate: #{impersonator_teammate&.id} (#{impersonator_teammate&.person&.full_name})"
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
    unless current_company_teammate
      flash[:error] = "You must be logged in to impersonate someone"
      redirect_to root_path
    end
  end

  def ensure_admin!
    unless current_company_teammate
      flash[:error] = "You must be logged in to impersonate someone"
      redirect_to root_path
      return
    end
    
    # Use Pundit policy for authorization
    unless policy(current_company_teammate.person).can_impersonate_anyone?
      flash[:error] = "Only administrators can impersonate users"
      redirect_to root_path
    end
  end

  def ensure_impersonating!
    unless impersonating?
      flash[:error] = "You are not currently impersonating anyone"
      redirect_to root_path
    end
  end
end
