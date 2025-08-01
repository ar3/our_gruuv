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
  
  # Helper method to capture errors in Sentry with context
  def capture_error_in_sentry(error, context = {})
    Sentry.capture_exception(error) do |event|
      # Add controller context if available
      if respond_to?(:controller_name) && respond_to?(:action_name)
        event.set_context('controller', {
          controller: controller_name,
          action: action_name
        })
        
        # Add params if available and filtered
        if respond_to?(:params) && params.respond_to?(:except)
          filtered_params = params.except(:controller, :action, :password, :password_confirmation)
          # Convert ActionController::Parameters to Hash for Sentry
          params_hash = filtered_params.respond_to?(:to_unsafe_h) ? filtered_params.to_unsafe_h : filtered_params
          event.set_context('params', params_hash)
        end
      end
      
      # Add custom context
      context.each do |key, value|
        # Sentry expects context values to be hashes or simple values
        if value.is_a?(Hash)
          event.set_context(key.to_s, value)
        else
          event.set_context(key.to_s, { value: value.to_s })
        end
      end
      
      # Add user context if available
      if respond_to?(:current_person) && current_person
        event.set_user(
          id: current_person.id,
          email: current_person.email,
          name: current_person.display_name
        )
      end
    end
  end
  
  def handle_standard_error(exception)
    # Capture the error in Sentry
    capture_error_in_sentry(exception, {
      method: 'global_error_handler',
      controller: controller_name,
      action: action_name
    })
    
    # Log the error
    Rails.logger.error "🚨 GLOBAL_ERROR_HANDLER: #{exception.class} - #{exception.message}"
    Rails.logger.error "🚨 GLOBAL_ERROR_HANDLER: Backtrace: #{exception.backtrace.first(10).join("\n")}"
    
    # In development, re-raise the exception to see the full error page
    if Rails.env.development?
      raise exception
    else
      # In production, show a generic error page
      flash[:error] = "An unexpected error occurred. Please try again."
      redirect_back(fallback_location: root_path)
    end
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
    capture_error_in_sentry(e, {
      method: 'get_or_create_person_from_session_or_params',
      session_person_id: session[:current_person_id],
      params_key: params_key
    })
    Rails.logger.error "🔍 GET_OR_CREATE_PERSON: Person not found in session: #{session[:current_person_id]}"
    Rails.logger.error "🔍 GET_OR_CREATE_PERSON: Clearing session and creating from params"
    session.delete(:current_person_id)
    find_or_create_person_from_params(params_key)
  rescue => e
    capture_error_in_sentry(e, {
      method: 'get_or_create_person_from_session_or_params',
      session_person_id: session[:current_person_id],
      params_key: params_key
    })
    Rails.logger.error "🔍 GET_OR_CREATE_PERSON: Error creating person from params: #{e.class} - #{e.message}"
    Rails.logger.error "🔍 GET_OR_CREATE_PERSON: Backtrace: #{e.backtrace.first(5).join("\n")}"
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
        Rails.logger.error "👤 FIND_OR_CREATE_PERSON_FROM_PARAMS: Email is blank!"
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
      Rails.logger.error "👤 FIND_OR_CREATE_PERSON_FROM_PARAMS: RecordInvalid error: #{e.message}"
      Rails.logger.error "👤 FIND_OR_CREATE_PERSON_FROM_PARAMS: Errors: #{e.record.errors.full_messages}"
      raise e
    rescue => e
      capture_error_in_sentry(e, {
        method: 'find_or_create_person_from_params',
        params_key: params_key
      })
      Rails.logger.error "👤 FIND_OR_CREATE_PERSON_FROM_PARAMS: Unexpected error: #{e.class} - #{e.message}"
      Rails.logger.error "👤 FIND_OR_CREATE_PERSON_FROM_PARAMS: Backtrace: #{e.backtrace.first(5).join("\n")}"
      raise e
    end
  end

  # Try to detect timezone from request headers
  def detect_timezone_from_request
    # Try to get timezone from Accept-Language header (limited but available)
    accept_language = request.headers['Accept-Language']
    if accept_language
      # Extract locale and try to map to timezone
      locale = accept_language.split(',').first&.strip
      timezone = map_locale_to_timezone(locale)
      return timezone if timezone && ActiveSupport::TimeZone.all.map(&:name).include?(timezone)
    end
    
    # Fallback to Eastern Time
    'Eastern Time (US & Canada)'
  end

  # Map common locales to timezones
  def map_locale_to_timezone(locale)
    return nil unless locale
    
    # Common locale to timezone mappings
    mappings = {
      'en-US' => 'Eastern Time (US & Canada)',
      'en-CA' => 'Eastern Time (US & Canada)',
      'en-GB' => 'London',
      'en-AU' => 'Sydney',
      'en-NZ' => 'Wellington',
      'fr-CA' => 'Eastern Time (US & Canada)',
      'fr-FR' => 'Paris',
      'de-DE' => 'Berlin',
      'es-ES' => 'Madrid',
      'es-MX' => 'Central Time (US & Canada)',
      'pt-BR' => 'Brasilia',
      'ja-JP' => 'Tokyo',
      'ko-KR' => 'Seoul',
      'zh-CN' => 'Beijing',
      'zh-TW' => 'Taipei'
    }
    
    mappings[locale] || mappings[locale.split('-').first]
  end
end
