class Organizations::CompanyTeammates::Asana::OauthController < ApplicationController
  before_action :require_authentication
  before_action :set_organization, except: [:callback]
  before_action :set_organization_from_state, only: [:callback]
  before_action :set_teammate, only: [:authorize]
  before_action :set_teammate_from_state, only: [:callback]

  def authorize
    # Generate OAuth URL for Asana
    client_id = ENV['ASANA_CLIENT_ID']
    redirect_uri = asana_oauth_callback_url
    # Request specific scopes needed for reading projects, sections, and tasks
    # If you have "Full Permissions" enabled in Asana app settings, you can use 'default'
    # Otherwise, use specific scopes like: 'default' or 'tasks:read projects:read'
    scope = ENV.fetch('ASANA_OAUTH_SCOPE', 'default') # Can be overridden via env var
    # Store source in state: 'one_on_one' or 'identities'
    source = params[:one_on_one_link_id].present? ? 'one_on_one' : 'identities'
    state = "#{@organization.id}_#{@teammate.id}_#{source}" # Use organization, teammate IDs, and source as state
    
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
            
            # Redirect based on where the request came from (stored in state)
            redirect_path = if @oauth_source == 'identities'
              organization_company_teammate_path(@organization, @teammate)
            else
              organization_company_teammate_one_on_one_link_path(@organization, @teammate)
            end
            
            redirect_to redirect_path, notice: 'Asana account connected successfully!'
          else
            redirect_path = if @oauth_source == 'identities'
              organization_company_teammate_path(@organization, @teammate)
            else
              organization_company_teammate_one_on_one_link_path(@organization, @teammate)
            end
            
            redirect_to redirect_path, alert: "Failed to save Asana identity: #{identity.errors.full_messages.join(', ')}"
          end
        else
          redirect_path = if @oauth_source == 'identities'
            organization_company_teammate_path(@organization, @teammate)
          else
            organization_company_teammate_one_on_one_link_path(@organization, @teammate)
          end
          
          redirect_to redirect_path, alert: 'Failed to get user information from Asana'
        end
      else
        redirect_path = if @oauth_source == 'identities'
          organization_company_teammate_path(@organization, @teammate)
        else
          organization_company_teammate_one_on_one_link_path(@organization, @teammate)
        end
        
        redirect_to redirect_path, alert: "Failed to connect Asana: #{data['error_description'] || data['error'] || 'Unknown error'}"
      end
    rescue => e
      Rails.logger.error "Asana OAuth error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      redirect_path = if @oauth_source == 'identities'
        organization_company_teammate_path(@organization, @teammate)
      else
        organization_company_teammate_one_on_one_link_path(@organization, @teammate)
      end
      
      redirect_to redirect_path, alert: "Failed to connect Asana: #{e.message}"
    end
  end

  private

  def set_organization
    @organization = Organization.find(params[:organization_id])
  end

  def set_teammate
    @teammate = @organization.teammates.find(params[:company_teammate_id])
    unless @teammate
      redirect_to organization_company_teammate_path(@organization, @teammate), 
                  alert: 'Teammate not found for this organization.'
    end
  end

  def set_organization_from_state
    state = params[:state]
    if state.present?
      parts = state.split('_')
      org_id = parts[0]
      teammate_id = parts[1]
      # Handle backward compatibility: old state format was just org_id_teammate_id
      # New format is org_id_teammate_id_source
      @oauth_source = parts[2] || 'one_on_one' # Default to one_on_one for backward compatibility
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








