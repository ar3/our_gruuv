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
    @current_person ||= Person.find(session[:current_person_id]) if session[:current_person_id]
  end

  # Get person from session or create from params
  def get_or_create_person_from_session_or_params(params_key = :huddle)
    if session[:current_person_id]
      Person.find(session[:current_person_id])
    else
      find_or_create_person_from_params(params_key)
    end
  end

  # Find or create person from specific params
  def find_or_create_person_from_params(params_key = :huddle)
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
    
    # If no timezone provided, try to detect from request
    timezone ||= detect_timezone_from_request
    
    # Find or create the person
    person = Person.find_or_create_by!(email: email) do |p|
      p.full_name = name
      p.timezone = timezone if timezone.present?
    end
    
    # Update the name and timezone if they changed
    updates = {}
    updates[:full_name] = name if person.full_name != name
    updates[:timezone] = timezone if timezone.present? && person.timezone != timezone
    
    person.update!(updates) if updates.any?
    
    person
  end

  # Try to detect timezone from request headers
  def detect_timezone_from_request
    # Try to get timezone from Accept-Language header (limited but available)
    accept_language = request.headers['Accept-Language']
    if accept_language
      # Extract locale and try to map to timezone
      locale = accept_language.split(',').first&.strip
      timezone = map_locale_to_timezone(locale)
      return timezone if timezone
    end
    
    # Fallback to UTC
    'UTC'
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
