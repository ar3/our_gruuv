class AuthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:google_oauth2_callback, :google_oauth2]
  
  def google_oauth2_callback
    auth = request.env['omniauth.auth']
    
    if auth.nil?
      redirect_to auth_failure_path, alert: 'Authentication failed'
      return
    end
    
    begin
      # Find or create person based on Google identity
      person = find_or_create_person_from_google_auth(auth)
      
      # Create or update Google identity
      create_or_update_google_identity(person, auth)
      
      # Set session
      session[:current_person_id] = person.id
      
      # Redirect to dashboard
      redirect_to dashboard_path, notice: 'Successfully signed in with Google!'
      
    rescue => e
      capture_error_in_sentry(e, {
        method: 'google_oauth2_callback',
        auth_provider: auth&.provider,
        auth_uid: auth&.uid,
        auth_email: auth&.info&.email
      })
      Rails.logger.error "🔐 GOOGLE_OAUTH_CALLBACK: Error: #{e.class} - #{e.message}"
      redirect_to auth_failure_path, alert: 'Authentication failed. Please try again.'
    end
  end
  
  def google_oauth2
    # This method is called when the OAuth flow is initiated
    # OmniAuth will handle the redirect to Google
    Rails.logger.info "🔐 GOOGLE_OAUTH_INITIATED: Request started"
    Rails.logger.info "🔐 GOOGLE_OAUTH_INITIATED: Request URL: #{request.url}"
    Rails.logger.info "🔐 GOOGLE_OAUTH_INITIATED: Request method: #{request.method}"
    Rails.logger.info "🔐 GOOGLE_OAUTH_INITIATED: OmniAuth full_host: #{OmniAuth.config.full_host}"
    Rails.logger.info "🔐 GOOGLE_OAUTH_INITIATED: Google Client ID: #{ENV['GOOGLE_CLIENT_ID']}"
    
    # Let OmniAuth handle the request
    # This should redirect to Google's OAuth page
  end
  
  def failure
    # This will be called if OAuth fails
    error_message = params[:message] || 'Authentication failed'
    redirect_to root_path, alert: error_message
  end
  
  private
  
  def find_or_create_person_from_google_auth(auth)
    # First, try to find by existing Google identity
    existing_identity = PersonIdentity.find_by(provider: 'google_oauth2', uid: auth.uid)
    if existing_identity
      return existing_identity.person
    end
    
    # Then, try to find by email
    email = auth.info.email
    existing_person = Person.find_by(email: email)
    if existing_person
      return existing_person
    end
    
    # Create new person
    Person.create!(
      email: email,
      full_name: auth.info.name || email.split('@').first.titleize,
      timezone: detect_timezone_from_request
    )
  end
  
  def create_or_update_google_identity(person, auth)
    identity = person.person_identities.find_or_initialize_by(provider: 'google_oauth2', uid: auth.uid)
    identity.email = auth.info.email
    identity.save!
  end
  
  def detect_timezone_from_request
    # Simple timezone detection - you might want to enhance this
    'Eastern Time (US & Canada)'
  end
end
