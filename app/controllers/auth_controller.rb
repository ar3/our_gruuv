class AuthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:google_oauth2_callback, :google_oauth2]
  
  def login
    # Redirect if already logged in
    if current_company_teammate
      redirect_to dashboard_organization_path(current_company_teammate.organization)
    end
  end
  
  def google_oauth2_callback
    auth = request.env['omniauth.auth']
    
    if auth.nil?
      redirect_to auth_failure_path, alert: 'Authentication failed'
      return
    end
    
    begin
      # Log the OAuth data for debugging
      Rails.logger.info "🔐 GOOGLE_OAUTH_DATA: #{auth.inspect}"
      Rails.logger.info "🔐 GOOGLE_OAUTH_UID: #{auth.uid}"
      Rails.logger.info "🔐 GOOGLE_OAUTH_EMAIL: #{auth.info.email}"
      Rails.logger.info "🔐 GOOGLE_OAUTH_NAME: #{auth.info.name}"
      Rails.logger.info "🔐 GOOGLE_OAUTH_FIRST_NAME: #{auth.info.first_name}"
      Rails.logger.info "🔐 GOOGLE_OAUTH_LAST_NAME: #{auth.info.last_name}"
      Rails.logger.info "🔐 GOOGLE_OAUTH_IMAGE: #{auth.info.image}"
      Rails.logger.info "🔐 GOOGLE_OAUTH_RAW_INFO: #{auth.extra.raw_info.inspect}"
      
      # Check if user is already logged in (connecting additional account)
      if current_company_teammate
        person = current_company_teammate.person
        create_or_update_google_identity(person, auth)
        redirect_to profile_path, notice: 'Google account connected successfully!'
      else
        # Normal sign-in flow
        person = find_or_create_person_from_google_auth(auth)
        create_or_update_google_identity(person, auth)
        
        # Ensure person has a teammate (creates "OurGruuv Demo" if needed)
        teammate = ensure_teammate_for_person(person)
        
        # Set session to use teammate
        session[:current_company_teammate_id] = teammate.id
        
        # Check for return path
        if session[:return_to].present?
          return_path = session[:return_to]
          session[:return_to] = nil
          redirect_to return_path, notice: 'Successfully signed in with Google!'
        else
          redirect_to dashboard_organization_path(teammate.organization), notice: 'Successfully signed in with Google!'
        end
      end
      
    rescue => e
      capture_error_in_sentry(e, {
        method: 'google_oauth2_callback',
        auth_provider: auth&.provider,
        auth_uid: auth&.info&.email
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
  
  def oauth_test
    @oauth_config = {
      google_client_id: ENV['GOOGLE_CLIENT_ID'],
      google_client_secret: ENV['GOOGLE_CLIENT_SECRET'],
      omniauth_full_host: OmniAuth.config.full_host,
      omniauth_allowed_methods: OmniAuth.config.allowed_request_methods,
      current_request_url: request.url,
      current_request_host: request.host,
      generated_callback_url: "#{OmniAuth.config.full_host}/auth/google_oauth2/callback",
      generated_authorize_url: "#{OmniAuth.config.full_host}/auth/google_oauth2"
    }
    begin
      test_response = Net::HTTP.get_response(URI("#{OmniAuth.config.full_host}/auth/google_oauth2"))
      @oauth_endpoint_response = test_response.code
      @oauth_endpoint_success = test_response.code == "200" || test_response.code == "302"
    rescue => e
      @oauth_endpoint_response = "ERROR: #{e.message}"
      @oauth_endpoint_success = false
    end
    render json: { oauth_config: @oauth_config, oauth_endpoint_response: @oauth_endpoint_response, oauth_endpoint_success: @oauth_endpoint_success }
  end

  def oauth_debug
    auth = request.env['omniauth.auth']
    if auth
      debug_data = {
        provider: auth.provider,
        uid: auth.uid,
        info: {
          name: auth.info.name,
          email: auth.info.email,
          first_name: auth.info.first_name,
          last_name: auth.info.last_name,
          image: auth.info.image,
          urls: auth.info.urls
        },
        credentials: {
          token: auth.credentials.token,
          refresh_token: auth.credentials.refresh_token,
          expires_at: auth.credentials.expires_at,
          expires: auth.credentials.expires
        },
        extra: {
          raw_info: auth.extra.raw_info
        }
      }
      render json: debug_data
    else
      render json: { error: 'No OAuth data available' }
    end
  end
  
  private
  
  def find_or_create_person_from_google_auth(auth)
    # First, try to find by existing Google identity
    existing_identity = PersonIdentity.find_by(provider: 'google_oauth2', uid: auth.uid)
    if existing_identity
      person = existing_identity.person
      # Ensure teammate exists
      ensure_teammate_for_person(person)
      return person
    end
    
    # Then, try to find by email
    email = auth.info.email
    existing_person = Person.find_by(email: email)
    if existing_person
      # Ensure teammate exists
      ensure_teammate_for_person(existing_person)
      return existing_person
    end
    
    # Create new person
    person = Person.create!(
      email: email,
      full_name: auth.info.name || email.split('@').first.titleize,
      timezone: detect_timezone_from_request
    )
    
    # Ensure teammate exists (will create "OurGruuv Demo" teammate)
    ensure_teammate_for_person(person)
    
    person
  end
  
  def create_or_update_google_identity(person, auth)
    identity = person.person_identities.find_or_initialize_by(provider: 'google_oauth2', uid: auth.uid)
    identity.email = auth.info.email
    identity.name = auth.info.name
    identity.profile_image_url = auth.info.image
    identity.raw_data = {
      'info' => {
        'name' => auth.info.name,
        'email' => auth.info.email,
        'first_name' => auth.info.first_name,
        'last_name' => auth.info.last_name,
        'image' => auth.info.image,
        'urls' => auth.info.urls
      },
      'credentials' => {
        'token' => auth.credentials.token,
        'refresh_token' => auth.credentials.refresh_token,
        'expires_at' => auth.credentials.expires_at,
        'expires' => auth.credentials.expires
      },
      'extra' => {
        'raw_info' => auth.extra.raw_info
      }
    }
    identity.save!
  end
  
  def detect_timezone_from_request
    # Simple timezone detection - you might want to enhance this
    'Eastern Time (US & Canada)'
  end
end
