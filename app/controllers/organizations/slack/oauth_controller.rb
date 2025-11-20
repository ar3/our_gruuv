class Organizations::Slack::OauthController < ApplicationController
  before_action :require_authentication
  before_action :set_organization, except: [:callback]
  before_action :set_organization_from_state, only: [:callback]
  
  def authorize
    # Generate OAuth URL for this specific organization
    client_id = ENV['SLACK_CLIENT_ID']
    redirect_uri = slack_oauth_callback_url
    scope = 'app_mentions:read,channels:history,channels:join,channels:read,chat:write,chat:write.customize,chat:write.public,commands,emoji:read,groups:history,groups:read,im:history,im:read,im:write,links:read,links:write,mpim:history,mpim:read,mpim:write,reactions:read,reactions:write,team:read,usergroups:read,usergroups:write,users.profile:read,users:read,users:read.email,users:write'    
    state = @organization.id.to_s # Use organization ID as state
    
    oauth_url = "https://slack.com/oauth/v2/authorize?client_id=#{client_id}&scope=#{scope}&redirect_uri=#{redirect_uri}&state=#{state}"
    
    redirect_to oauth_url, allow_other_host: true
  end
  
  def callback
    code = params[:code]
    
    begin
      # Exchange code for access token
      client_id = ENV['SLACK_CLIENT_ID']
      client_secret = ENV['SLACK_CLIENT_SECRET']
      redirect_uri = slack_oauth_callback_url
      
      response = HTTP.post('https://slack.com/api/oauth.v2.access', form: {
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        redirect_uri: redirect_uri
      })
      
      data = JSON.parse(response.body.to_s)
      
      if data['ok']
        # Create or update Slack configuration for this organization
        config = @organization.slack_configuration || @organization.build_slack_configuration
        
        config.update!(
          bot_token: data['access_token'],
          workspace_id: data['team']['id'],
          workspace_name: data['team']['name'],
          workspace_subdomain: nil, # We'll get this from team.info API call
          workspace_url: nil, # We'll set this after getting the subdomain
          bot_user_id: data['bot_user_id'],
          installed_at: Time.current,
          created_by_id: current_person&.id
        )
        
        # Store the full OAuth response for debugging (after config is saved)
        DebugResponse.create!(
          responseable: config,
          request: {
            client_id: client_id,
            code: code,
            redirect_uri: redirect_uri
          },
          response: data,
          notes: "Slack OAuth v2 access response"
        )
        
        # Get workspace subdomain using team.info API
        begin
          client = Slack::Web::Client.new(token: data['access_token'])
          team_info = client.team_info
          
          if team_info['ok'] && team_info['team']['domain']
            config.update!(
              workspace_subdomain: team_info['team']['domain'],
              workspace_url: "https://#{team_info['team']['domain']}.slack.com"
            )
            
            # Store the team.info response for debugging
            DebugResponse.create!(
              responseable: config,
              request: { method: 'team.info' },
              response: team_info,
              notes: "Slack team.info API response"
            )
          end
        rescue => e
          Rails.logger.error "Failed to get team info: #{e.message}"
          # Store the error for debugging
          DebugResponse.create!(
            responseable: config,
            request: { method: 'team.info' },
            response: { error: e.message, backtrace: e.backtrace.first(5) },
            notes: "Slack team.info API error"
          )
        end
        
        redirect_to organization_slack_path(@organization), notice: "Slack successfully connected to #{@organization.display_name}!"
      else
        redirect_to organization_slack_path(@organization), alert: "Failed to connect Slack: #{data['error']}"
      end
    rescue => e
      Rails.logger.error "Slack OAuth error: #{e.message}"
      redirect_to organization_slack_path(@organization), alert: "Failed to connect Slack: #{e.message}"
    end
  end
  
  def uninstall
    # Remove Slack configuration for this organization
    if @organization.slack_configuration&.destroy
      redirect_to organization_slack_path(@organization), notice: "Slack has been uninstalled from #{@organization.display_name}"
    else
      redirect_to organization_slack_path(@organization), alert: "Failed to uninstall Slack"
    end
  end
  
  private
  
  def set_organization
    @organization = Organization.find(params[:organization_id])
  end
  
  def set_organization_from_state
    state = params[:state]
    if state.present?
      @organization = Organization.find(state)
    else
      redirect_to root_path, alert: 'Invalid OAuth callback: missing state parameter'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Invalid OAuth callback: organization not found'
  end
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access Slack integration.'
    end
  end
end 