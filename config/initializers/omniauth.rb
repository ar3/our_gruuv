Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, 
    ENV['GOOGLE_CLIENT_ID'],
    ENV['GOOGLE_CLIENT_SECRET'],
    {
      scope: 'email,profile',
      prompt: 'select_account',
      access_type: 'online'
    }
end

# Configure OmniAuth to use Rails sessions
OmniAuth.config.allowed_request_methods = [:post, :get]
OmniAuth.config.silence_get_warning = true

# Set the full host for OmniAuth
OmniAuth.config.full_host = ENV['RAILS_HOST'] ? "https://#{ENV['RAILS_HOST']}" : (Rails.env.production? ? 'https://yourdomain.com' : 'http://localhost:3000')

# Enable OmniAuth test mode in development
if Rails.env.development?
  OmniAuth.config.test_mode = false
end
