class Slack::OauthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:callback]
  
  # Slack OAuth app configuration
  SLACK_CLIENT_ID = ENV['SLACK_CLIENT_ID']
  SLACK_CLIENT_SECRET = ENV['SLACK_CLIENT_SECRET']
  SLACK_REDIRECT_URI = ENV['SLACK_REDIRECT_URI'] || "#{ENV['RAILS_HOST'] || 'http://localhost:3000'}/slack/oauth/callback"
  
  def authorize
    # Store the organization ID in session for the callback
    session[:slack_oauth_organization_id] = params[:organization_id]
    
    # Build the Slack OAuth URL
    oauth_url = "https://slack.com/oauth/v2/authorize?" + {
      client_id: SLACK_CLIENT_ID,
      scope: 'chat:write,channels:read,groups:read,users:read',
      redirect_uri: SLACK_REDIRECT_URI,
      state: generate_state_token
    }.to_query
    
    redirect_to oauth_url, allow_other_host: true
  end
  
  def callback
    # Verify the state parameter to prevent CSRF
    unless valid_state_token?(params[:state])
      redirect_to slack_path, alert: 'Invalid OAuth state parameter'
      return
    end
    
    # Exchange the authorization code for an access token
    token_response = exchange_code_for_token(params[:code])
    
    if token_response['ok']
      # Get workspace info
      workspace_info = get_workspace_info(token_response['access_token'])
      
      if workspace_info['ok']
        # Find or create the organization
        organization = find_organization_from_session
        
        if organization
          # Create or update the Slack configuration
          slack_config = organization.slack_configuration || organization.build_slack_configuration
          slack_config.assign_attributes(
            workspace_id: workspace_info['team']['id'],
            workspace_name: workspace_info['team']['name'],
            bot_token: token_response['access_token'],
            default_channel: '#general',
            bot_username: 'Huddle Bot',
            bot_emoji: ':huddle:',
            installed_at: Time.current
          )
          
          if slack_config.save
            redirect_to slack_path, notice: "Slack successfully installed for #{organization.display_name}!"
          else
            redirect_to slack_path, alert: "Failed to save Slack configuration: #{slack_config.errors.full_messages.join(', ')}"
          end
        else
          redirect_to slack_path, alert: 'Organization not found'
        end
      else
        redirect_to slack_path, alert: "Failed to get workspace info: #{workspace_info['error']}"
      end
    else
      redirect_to slack_path, alert: "Failed to exchange code for token: #{token_response['error']}"
    end
  rescue => e
    Rails.logger.error "Slack OAuth error: #{e.message}"
    redirect_to slack_path, alert: 'An error occurred during Slack installation'
  end
  
  def uninstall
    organization = find_organization_from_params
    
    if organization&.slack_configuration
      organization.slack_configuration.destroy
      redirect_to slack_path, notice: "Slack uninstalled from #{organization.display_name}"
    else
      redirect_to slack_path, alert: 'No Slack configuration found to uninstall'
    end
  end
  
  private
  
  def exchange_code_for_token(code)
    uri = URI('https://slack.com/api/oauth.v2.access')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request.set_form_data({
      client_id: SLACK_CLIENT_ID,
      client_secret: SLACK_CLIENT_SECRET,
      code: code,
      redirect_uri: SLACK_REDIRECT_URI
    })
    
    response = http.request(request)
    JSON.parse(response.body)
  end
  
  def get_workspace_info(token)
    uri = URI('https://slack.com/api/team.info')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{token}"
    
    response = http.request(request)
    JSON.parse(response.body)
  end
  
  def find_organization_from_session
    organization_id = session[:slack_oauth_organization_id]
    session.delete(:slack_oauth_organization_id)
    
    Organization.find_by(id: organization_id) if organization_id
  end
  
  def find_organization_from_params
    Organization.find_by(id: params[:organization_id])
  end
  
  def generate_state_token
    SecureRandom.hex(32).tap do |token|
      session[:slack_oauth_state] = token
    end
  end
  
  def valid_state_token?(state)
    session[:slack_oauth_state] == state.tap do
      session.delete(:slack_oauth_state)
    end
  end
end 