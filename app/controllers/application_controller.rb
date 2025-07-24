class ApplicationController < ActionController::Base
  include Pundit::Authorization
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  layout :determine_layout
  
  def logout
    session.clear
    redirect_to root_path, notice: 'You have been logged out successfully!'
  end
  
  helper_method :current_person
  helper_method :current_organization
  
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  # Override Pundit's default user method to use current_person
  def pundit_user
    current_person
  end
  
  private
  
  def user_not_authorized
    # For huddle-related actions where user is not a participant, redirect to join page
    if @_pundit_policy_record.is_a?(Huddle) && 
       [:feedback?, :submit_feedback?, :summary?].include?(@_pundit_policy_query&.to_sym)
      flash[:alert] = "Please join the huddle before accessing this page."
      redirect_to join_huddle_path(@_pundit_policy_record)
      return
    end
    
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back(fallback_location: root_path)
  end

  # Override Pundit's authorize method to capture context for custom redirects
  def authorize(record, query = nil, policy_class: nil)
    query ||= params[:action].to_s + "?"
    
    @_pundit_policy_record = record
    @_pundit_policy_query = query
    
    super
  end
  
  def determine_layout
    current_person ? 'authenticated' : 'application'
  end
  
  def current_person
    return @current_person if defined?(@current_person)
    
    if session[:current_person_id]
      begin
        @current_person = Person.find(session[:current_person_id])
      rescue ActiveRecord::RecordNotFound
        # Clear the invalid session
        session.delete(:current_person_id)
        @current_person = nil
        
        # Show error message
        flash[:error] = "Your session has expired or is invalid. Please log in again."
      end
    else
      @current_person = nil
    end
    
    @current_person
  end

  def current_organization
    return nil unless current_person
    current_person.current_organization_or_default
  end

  # Get person from session or create from params
  def get_or_create_person_from_session_or_params(params_key = :huddle)
    if session[:current_person_id]
      Person.find(session[:current_person_id])
    else
      find_or_create_person_from_params(params_key)
    end
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "🔍 GET_OR_CREATE_PERSON: Person not found in session: #{session[:current_person_id]}"
    Rails.logger.error "🔍 GET_OR_CREATE_PERSON: Clearing session and creating from params"
    session.delete(:current_person_id)
    find_or_create_person_from_params(params_key)
  rescue => e
    Rails.logger.error "🔍 GET_OR_CREATE_PERSON: Error creating person from params: #{e.class} - #{e.message}"
    Rails.logger.error "🔍 GET_OR_CREATE_PERSON: Backtrace: #{e.backtrace.first(5).join("\n")}"
    raise e
  end

  # Find or create person from specific params
  def find_or_create_person_from_params(params_key = :huddle)
    # For join params, they're at the top level, not nested
    if params_key == :join
      email = params[:email]
      timezone = params[:timezone]
    else
      params_obj = params[params_key]
      email = params_obj[:email]
      name = params_obj[:name]
      timezone = params_obj[:timezone]
    end
    
    # Validate required fields
    if email.blank?
      Rails.logger.error "👤 FIND_OR_CREATE_PERSON_FROM_PARAMS: Email is blank!"
      raise ActiveRecord::RecordInvalid.new(Person.new), "Email is required"
    end
    
    # Find or create the person
    person = Person.find_or_create_by!(email: email)
    
    # If no timezone provided, try to detect from request
    timezone ||= TimezoneService.detect_from_request(request)
    
    # Use provided name or auto-generate from email
    maybe_new_name = name.presence || email.split('@').first.gsub('.', ' ').titleize
    
    # Update the name and timezone if they changed
    updates = {}
    updates[:full_name] = maybe_new_name if person.full_name.blank? || (name.present? && person.full_name != name)
    updates[:timezone] = timezone if timezone.present? && person.timezone.blank?
    
    person.update!(updates) if updates.any?
    
    person
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "👤 FIND_OR_CREATE_PERSON_FROM_PARAMS: RecordInvalid error: #{e.message}"
    Rails.logger.error "👤 FIND_OR_CREATE_PERSON_FROM_PARAMS: Errors: #{e.record.errors.full_messages}"
    raise e
  rescue => e
    Rails.logger.error "👤 FIND_OR_CREATE_PERSON_FROM_PARAMS: Unexpected error: #{e.class} - #{e.message}"
    Rails.logger.error "👤 FIND_OR_CREATE_PERSON_FROM_PARAMS: Backtrace: #{e.backtrace.first(5).join("\n")}"
    raise e
  end
  
end
