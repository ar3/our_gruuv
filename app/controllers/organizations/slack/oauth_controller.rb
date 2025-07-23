class Organizations::Slack::OauthController < ApplicationController
  before_action :require_authentication
  before_action :set_organization
  
  def authorize
    # Generate OAuth URL for this specific organization
    client_id = ENV['SLACK_CLIENT_ID']
    redirect_uri = organization_slack_oauth_callback_url(@organization)
    scope = 'identify,bot,commands,channels:read,channels:history,emoji:read,reactions:read,users:read,channels:write,chat:write:bot,reactions:write,reminders:write'    
    state = @organization.id.to_s # Use organization ID as state
    
    oauth_url = "https://slack.com/oauth/v2/authorize?client_id=#{client_id}&scope=#{scope}&redirect_uri=#{redirect_uri}&state=#{state}"
    
    redirect_to oauth_url
  end
  
  def callback
    code = params[:code]
    state = params[:state]
    
    # Verify state matches organization ID
    unless state == @organization.id.to_s
      redirect_to organization_slack_path(@organization), alert: 'Invalid OAuth state'
      return
    end
    
    begin
      # Exchange code for access token
      client_id = ENV['SLACK_CLIENT_ID']
      client_secret = ENV['SLACK_CLIENT_SECRET']
      redirect_uri = organization_slack_oauth_callback_url(@organization)
      
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
          workspace_url: "https://#{data['team']['domain']}.slack.com",
          bot_user_id: data['bot_user_id']
        )
        
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
  
  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access Slack integration.'
    end
  end
end 