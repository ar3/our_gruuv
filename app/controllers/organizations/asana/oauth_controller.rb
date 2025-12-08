class Organizations::Asana::OauthController < ApplicationController
  before_action :require_authentication
  before_action :set_organization, except: [:callback]
  before_action :set_organization_from_state, only: [:callback]
  before_action :set_person_and_teammate, only: [:authorize]
  before_action :set_teammate_from_state, only: [:callback]

  def authorize
    # Generate OAuth URL for Asana
    client_id = ENV['ASANA_CLIENT_ID']
    redirect_uri = asana_oauth_callback_url
    # Request specific scopes needed for reading projects, sections, and tasks
    # If you have "Full Permissions" enabled in Asana app settings, you can use 'default'
    # Otherwise, use specific scopes like: 'default' or 'tasks:read projects:read'
    scope = ENV.fetch('ASANA_OAUTH_SCOPE', 'default') # Can be overridden via env var
    state = "#{@organization.id}_#{@teammate.id}" # Use organization and teammate IDs as state
    
    oauth_url = "https://app.asana.com/-/oauth_authorize?client_id=#{client_id}&redirect_uri=#{CGI.escape(redirect_uri)}&response_type=code&scope=#{CGI.escape(scope)}&state=#{CGI.escape(state)}"
    
    redirect_to oauth_url, allow_other_host: true
  end
  
  def callback
    code = params[:code]
    
    begin
      # Exchange code for access token
      client_id = ENV['ASANA_CLIENT_ID']
      client_secret = ENV['ASANA_CLIENT_SECRET']
      redirect_uri = asana_oauth_callback_url
      
      response = HTTP.post('https://app.asana.com/-/oauth_token', form: {
        grant_type: 'authorization_code',
        client_id: client_id,
        client_secret: client_secret,
        code: code,
        redirect_uri: redirect_uri
      })
      
      data = JSON.parse(response.body.to_s)
      
      if data['access_token']
        # Get user info from Asana
        user_response = HTTP.auth("Bearer #{data['access_token']}")
                            .get('https://app.asana.com/api/1.0/users/me')
        
        user_data = JSON.parse(user_response.body.to_s)
        
        if user_data['data']
          user_info = user_data['data']
          
          # Create or update Asana identity for the teammate
          identity = @teammate.teammate_identities.find_or_initialize_by(provider: 'asana')
          identity.uid = user_info['gid']
          identity.email = user_info['email']
          identity.name = user_info['name']
          identity.profile_image_url = user_info.dig('photo', 'image_128x128')
          identity.raw_data = {
            'info' => user_info,
            'credentials' => {
              'token' => data['access_token'],
              'refresh_token' => data['refresh_token'],
              'expires_at' => data['expires_in'] ? Time.current + data['expires_in'].seconds : nil
            },
            'extra' => data
          }
          
          if identity.save
            # If there's a one-on-one link with Asana project, mark it as integrated
            one_on_one_link = @teammate.one_on_one_link
            if one_on_one_link&.is_asana_link? && one_on_one_link.asana_project_id
              one_on_one_link.deep_integration_config ||= {}
              one_on_one_link.deep_integration_config['asana_project_id'] ||= extract_asana_project_id(one_on_one_link.url)
              one_on_one_link.save
            end
            
            redirect_to organization_person_one_on_one_link_path(@organization, @teammate.person), 
                        notice: 'Asana account connected successfully!'
          else
            redirect_to organization_person_one_on_one_link_path(@organization, @teammate.person), 
                        alert: "Failed to save Asana identity: #{identity.errors.full_messages.join(', ')}"
          end
        else
          redirect_to organization_person_one_on_one_link_path(@organization, @teammate.person), 
                      alert: 'Failed to get user information from Asana'
        end
      else
        redirect_to organization_person_one_on_one_link_path(@organization, @teammate.person), 
                    alert: "Failed to connect Asana: #{data['error_description'] || data['error'] || 'Unknown error'}"
      end
    rescue => e
      Rails.logger.error "Asana OAuth error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      redirect_to organization_person_one_on_one_link_path(@organization, @teammate.person), 
                  alert: "Failed to connect Asana: #{e.message}"
    end
  end

  private

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_person_and_teammate
    @person = Person.find(params[:person_id])
    @teammate = @person.teammates.find_by(organization: @organization)
    unless @teammate
      redirect_to organization_person_path(@organization, @person), 
                  alert: 'Teammate not found for this organization.'
    end
  end

  def set_organization_from_state
    state = params[:state]
    if state.present?
      org_id, teammate_id = state.split('_')
      @organization = Organization.find(org_id)
      @teammate = Teammate.find(teammate_id)
    else
      redirect_to root_path, alert: 'Invalid OAuth callback: missing state parameter'
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to root_path, alert: 'Invalid OAuth callback: organization or teammate not found'
  end

  def set_teammate_from_state
    # Already set in set_organization_from_state
  end

  def extract_asana_project_id(url)
    AsanaUrlParser.extract_project_id(url)
  end

  def require_authentication
    unless current_person
      redirect_to root_path, alert: 'Please log in to access Asana integration.'
    end
  end
end

