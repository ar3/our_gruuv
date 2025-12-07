require 'ostruct'

class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include Pagy::Backend
  
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  layout :determine_layout
  
  # Allow CSRF token validation for ngrok domains
  protect_from_forgery with: :exception, prepend: true
  
  # Global exception handler to prevent silent failures
  rescue_from StandardError, with: :handle_unexpected_error
  
  def logout
    session.clear
    redirect_to root_path, notice: 'You have been logged out successfully!'
  end
  
  helper_method :current_company_teammate
  helper_method :current_person
  helper_method :current_organization
  helper_method :impersonating?
  helper_method :impersonating_teammate
  helper_method :recent_page_visits
  helper_method :current_user_preferences
  
  private
  
  def handle_unexpected_error(exception)
    Rails.logger.error "ApplicationController: Unexpected error in #{controller_name}##{action_name}: #{exception.class.name}: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")
    
    # Don't handle errors in development/test - let them bubble up for debugging
    if Rails.env.development? || Rails.env.test?
      raise exception
    end
    
    # In production, show a generic error page
    respond_to do |format|
      format.html { render 'shared/error', status: :internal_server_error }
      format.json { render json: { error: 'An unexpected error occurred' }, status: :internal_server_error }
    end
  end
  
  
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  
  # Set up PaperTrail controller info for request tracking
  before_action :set_paper_trail_controller_info
  
  # Track page visits for recently visited feature
  after_action :track_page_visit
  
  # Override Pundit's default user method to use current_company_teammate
  def pundit_user
    OpenStruct.new(
      user: current_company_teammate,
      impersonating_teammate: impersonating_teammate
    )
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
      if respond_to?(:current_company_teammate) && current_company_teammate
        person = current_company_teammate.person
        event.set_user(
          id: person.id,
          email: person.email,
          name: person.display_name
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
  
  def authenticate_person!
    unless current_company_teammate
      flash[:error] = "You must be logged in to access this page"
      redirect_to root_path
    end
  end
  
  def user_not_authorized
    # For huddle-related actions where user is not a participant, redirect to join page
    if @_pundit_policy_record.is_a?(Huddle) && 
       [:feedback?, :submit_feedback?, :summary?].include?(@_pundit_policy_query&.to_sym)
      flash[:alert] = "Please join the huddle before accessing this page."
      redirect_to join_huddle_path(@_pundit_policy_record)
      return
    end
    
    # For person-related actions, redirect to public view if possible
    if @_pundit_policy_record.is_a?(Person) && 
       [:show?, :teammate?, :manager?, :view_check_ins?].include?(@_pundit_policy_query&.to_sym)
      flash[:alert] = "You don't have permission to view that profile. Here's the public information that's available to you."
      redirect_to public_person_path(@_pundit_policy_record)
      return
    end
    
    # Default: redirect to homepage to prevent redirect loops
    flash[:alert] = "You don't have permission to access that resource. Please contact your administrator if you believe this is an error."
    redirect_to root_path
  end
  


  # Override Pundit's authorize method to capture context for custom redirects
  def authorize(record, query = nil, **options)
    query ||= params[:action].to_s + "?"
    
    @_pundit_policy_record = record
    @_pundit_policy_query = query
    
    super(record, query, **options)
  end
  
  def determine_layout
    return 'application' unless current_company_teammate
    
    # Check user preference for layout, default to horizontal
    if current_user_preferences&.layout == 'vertical'
      'authenticated-vertical-navigation'
    else
      'authenticated-horizontal-navigation'
    end
  end
  
  def current_company_teammate
    # Rails.logger.info "🔍🔍🔍🔍🔍 START_current_company_teammate: Does it exist already? #{@current_company_teammate.present?}: #{@current_company_teammate&.id} (#{@current_company_teammate&.person&.display_name})"
    return @current_company_teammate if @current_company_teammate.present?
    
    # In test environment, allow RSpec mocks to override
    if Rails.env.test? && respond_to?(:current_company_teammate_mock)
      return current_company_teammate_mock if current_company_teammate_mock
    end
    
    if session[:current_company_teammate_id]
      begin
        @current_company_teammate = CompanyTeammate.find(session[:current_company_teammate_id])
        # Ensure teammate is still active (not terminated)
        if @current_company_teammate.last_terminated_at.present?
          # Teammate was terminated, clear session
          session.delete(:current_company_teammate_id)
          @current_company_teammate = nil
          flash[:error] = "Your session has expired. Please log in again."
        end
      rescue ActiveRecord::RecordNotFound
        # Clear the invalid session
        session.delete(:current_company_teammate_id)
        @current_company_teammate = nil
        
        # Show error message
        flash[:error] = "Your session has expired or is invalid. Please log in again."
      end
    else
      @current_company_teammate = nil
    end
    
    @current_company_teammate
  end

  # Helper method that delegates to current_company_teammate.person for backward compatibility
  def current_person
    current_company_teammate&.person
  end

  # Helper method that delegates to current_company_teammate.organization
  def current_organization
    current_company_teammate&.organization
  end
  
  # Helper method to get or create user preferences
  def current_user_preferences
    return nil unless current_person
    @current_user_preferences ||= UserPreference.for_person(current_person)
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

  # Impersonation helper methods
  def impersonating?
    session[:impersonating_teammate_id].present?
  end

  def impersonating_teammate
    begin
      return @impersonating_teammate = nil unless session[:impersonating_teammate_id].present?
      @impersonating_teammate ||= CompanyTeammate.find(session[:impersonating_teammate_id])
    rescue ActiveRecord::RecordNotFound
      nil
    end
  end

  def start_impersonation(teammate)
    Rails.logger.info "🔍🔍🔍🔍🔍 START_IMPERSONATION: About to start impersonation for teammate: #{teammate&.id} (#{teammate&.person&.display_name})"
    Rails.logger.info "🔍🔍🔍🔍🔍 START_IMPERSONATION: pundit: #{pundit_user}"
    
    @impersonating_teammate = nil
    @current_company_teammate = nil

    # Use Pundit policy for authorization (check if real user can impersonate the teammate's person)
    return false unless policy(teammate.person).can_impersonate?
    Rails.logger.info "🔍🔍🔍🔍🔍 START_IMPERSONATION: session[:current_company_teammate_id]: #{session[:current_company_teammate_id]}"
    Rails.logger.info "🔍🔍🔍🔍🔍 START_IMPERSONATION: session[:impersonating_teammate_id]: #{session[:impersonating_teammate_id]}"
    session[:impersonating_teammate_id] = session[:current_company_teammate_id]
    session[:current_company_teammate_id] = teammate.id
    raise "Impersonation failed because current_company_teammate.id (#{current_company_teammate&.id}) != teammate.id (#{teammate.id})" if current_company_teammate&.id != teammate.id
    Rails.logger.info "🔍🔍🔍🔍🔍 IMPERSONATION_COMPLETE: session[:current_company_teammate_id]: #{session[:current_company_teammate_id]}"
    Rails.logger.info "🔍🔍🔍🔍🔍 IMPERSONATION_COMPLETE: session[:impersonating_teammate_id]: #{session[:impersonating_teammate_id]}"
    true
  end

  def stop_impersonation
    return false unless impersonating?
    @impersonating_teammate = nil
    @current_company_teammate = nil

    session[:current_company_teammate_id] = session[:impersonating_teammate_id]
    session.delete(:impersonating_teammate_id)
    true
  end
  
  # Set PaperTrail controller info for request tracking
  def set_paper_trail_controller_info
    # Only set controller info that can be stored in the meta JSONB column
    PaperTrail.request.controller_info = {
      current_teammate_id: current_company_teammate&.id,
      impersonating_teammate_id: impersonating? ? session[:impersonating_teammate_id] : nil
    }
  end

  # Ensure person has at least one active teammate, creating "OurGruuv Demo" teammate if needed
  def ensure_teammate_for_person(person)
    return nil unless person
    
    # Find active teammates (not terminated)
    active_teammates = person.active_teammates.where(type: 'CompanyTeammate')
    
    # If person has active teammates, return the first one
    return active_teammates.first if active_teammates.any?
    
    # No active teammates - create one in "OurGruuv Demo" organization
    demo_org = Company.find_by(name: 'OurGruuv Demo')
    unless demo_org
      Rails.logger.error "OurGruuv Demo organization not found! Run db:seed to create it."
      raise "OurGruuv Demo organization not found. Please run db:seed."
    end
    
    # Create CompanyTeammate as a follower (no employment dates)
    person.teammates.create!(
      organization: demo_org,
      type: 'CompanyTeammate',
      first_employed_at: nil,
      last_terminated_at: nil
    )
  end

  # Ensure teammate is a CompanyTeammate for the root company
  # If the teammate is already a CompanyTeammate for the root company, return it
  # Otherwise, find or create a CompanyTeammate for the root company
  def ensure_company_teammate(teammate)
    return nil unless teammate
    
    # If teammate is already a CompanyTeammate for the root company, return it
    return teammate if teammate.is_a?(CompanyTeammate)

    # If person has active teammates, return the first one
    active_teammates = teammate.person.active_teammates.where(type: 'CompanyTeammate')
    return active_teammates.first if active_teammates.any?

    root_company = teammate.organization.root_company || teammate.organization
    return nil unless root_company.is_a?(Company)
    
    # Find or create CompanyTeammate for root company... because the only way this is possible is if the person is a member of a department or team within a company.. this will make them a watcher of that company.
    teammate.person.teammates.find_or_create_by!(
      organization: root_company
    ) do |t|
      t.type = 'CompanyTeammate'
      t.first_employed_at = nil
      t.last_terminated_at = nil
    end
  end

  # Helper method for recent page visits
  def recent_page_visits
    return PageVisit.none unless current_person
    PageVisit.recent.for_person(current_person).limit(30)
  end

  # Track page visits for recently visited feature
  def track_page_visit
    # Skip tracking if no current person
    return unless current_person
    
    # Skip tracking for root path
    return if request.path == '/' || request.path == root_path
    
    # Skip tracking for non-HTML requests
    return unless request.format.html?
    
    # Skip tracking for AJAX requests
    return if request.xhr?
    
    # Skip tracking for API endpoints (if path starts with /api)
    return if request.path.start_with?('/api')
    
    # Get page title - try to get from content_for, fallback to controller/action
    # Note: In after_action, content_for may not be directly accessible
    # We'll use the fallback for now and can improve title extraction later
    page_title = begin
      # Try to access content_for if available
      if respond_to?(:content_for) && content_for?(:title)
        content_for(:title)
      else
        "#{controller_name.humanize} #{action_name.humanize}"
      end
    rescue => e
      # Fallback to controller/action name
      "#{controller_name.humanize} #{action_name.humanize}"
    end
    
    # Get full URL with query params
    url = request.fullpath
    
    # Get user agent
    user_agent = request.user_agent
    Rails.logger.info "🔍 PageVisit: About to call PageVisitJob.perform_now"
    # Call perform directly on an instance to bypass ActiveJob queue adapter issues
    PageVisitJob.new.perform(current_person.id, url, page_title, user_agent)
  rescue => e
    # Don't let tracking errors break the request
    Rails.logger.error "PageVisit tracking error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
end
