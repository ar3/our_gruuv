class AsanaService

  def initialize(teammate)
    @teammate = teammate
    @identity = teammate.asana_identity
  end

  def authenticated?
    @identity.present? && access_token.present?
  end

  def access_token
    @identity&.raw_credentials&.dig('token')
  end

  def refresh_token
    @identity&.raw_credentials&.dig('refresh_token')
  end

  def refresh_access_token
    return false unless refresh_token.present?

    begin
      client_id = ENV['ASANA_CLIENT_ID']
      client_secret = ENV['ASANA_CLIENT_SECRET']

      response = HTTP.post('https://app.asana.com/-/oauth_token', form: {
        grant_type: 'refresh_token',
        client_id: client_id,
        client_secret: client_secret,
        refresh_token: refresh_token
      })

      data = JSON.parse(response.body.to_s)

      if data['access_token']
        # Update identity with new tokens
        @identity.raw_data ||= {}
        @identity.raw_data['credentials'] ||= {}
        @identity.raw_data['credentials']['token'] = data['access_token']
        @identity.raw_data['credentials']['refresh_token'] = data['refresh_token'] if data['refresh_token']
        @identity.raw_data['credentials']['expires_at'] = data['expires_in'] ? Time.current + data['expires_in'].seconds : nil
        @identity.save
        true
      else
        Rails.logger.error "Asana token refresh failed: #{data['error'] || 'Unknown error'}"
        false
      end
    rescue => e
      Rails.logger.error "Asana token refresh error: #{e.message}"
      false
    end
  end

  def fetch_project(project_id)
    return nil unless authenticated?
    
    begin
      response = HTTP.auth("Bearer #{access_token}")
                      .get("https://app.asana.com/api/1.0/projects/#{project_id}")
      
      data = JSON.parse(response.body.to_s)
      data['data'] if data['data']
    rescue => e
      Rails.logger.error "Asana API error: #{e.message}"
      nil
    end
  end

  def fetch_project_sections(project_id)
    return { success: false, error: 'not_authenticated', message: 'Not authenticated with Asana' } unless authenticated?
    
    begin
      response = HTTP.auth("Bearer #{access_token}")
                      .get("https://app.asana.com/api/1.0/projects/#{project_id}/sections")
      
      result = handle_api_response(response, 'fetch_project_sections')
      
      # If token was refreshed, retry the request
      if result[:error] == 'retry'
        response = HTTP.auth("Bearer #{access_token}")
                        .get("https://app.asana.com/api/1.0/projects/#{project_id}/sections")
        result = handle_api_response(response, 'fetch_project_sections')
      end
      
      if result[:success]
        { success: true, sections: result[:data]['data'] || [] }
      else
        result
      end
    rescue => e
      Rails.logger.error "Asana fetch_project_sections error: #{e.message}"
      { success: false, error: 'network_error', message: "Failed to connect to Asana: #{e.message}" }
    end
  end

  def fetch_section_tasks(section_id, include_completed: false, completed_since: nil)
    return { success: false, error: 'not_authenticated', message: 'Not authenticated with Asana' } unless authenticated?
    
    begin
      params = {
        opt_fields: 'name,completed,assignee.name,assignee.gid,due_on,gid,completed_at,created_at,tags.name,tags.color,tags.gid'
      }
      
      if include_completed && completed_since
        params[:completed_since] = completed_since.iso8601
      elsif !include_completed
        params[:completed_since] = 'now' # Only incomplete tasks
      end
      
      response = HTTP.auth("Bearer #{access_token}")
                      .get("https://app.asana.com/api/1.0/sections/#{section_id}/tasks", params: params)
      
      result = handle_api_response(response, 'fetch_section_tasks')
      
      # If token was refreshed, retry the request
      if result[:error] == 'retry'
        response = HTTP.auth("Bearer #{access_token}")
                        .get("https://app.asana.com/api/1.0/sections/#{section_id}/tasks", params: params)
        result = handle_api_response(response, 'fetch_section_tasks')
      end
      
      if result[:success]
        { success: true, tasks: result[:data]['data'] || [] }
      else
        result
      end
    rescue => e
      Rails.logger.error "Asana fetch_section_tasks error: #{e.message}"
      { success: false, error: 'network_error', message: "Failed to connect to Asana: #{e.message}" }
    end
  end

  def fetch_all_project_tasks(project_id)
    return { success: false, error: 'not_authenticated', message: 'Not authenticated with Asana' } unless authenticated?
    
    sections_result = fetch_project_sections(project_id)
    return sections_result unless sections_result[:success]
    
    sections = sections_result[:sections]
    incomplete_tasks = []
    completed_tasks = []
    cutoff_date = 14.days.ago
    
    sections.each do |section|
      # Fetch incomplete tasks
      incomplete_result = fetch_section_tasks(section['gid'], include_completed: false)
      if incomplete_result[:success]
        incomplete_result[:tasks].each do |task|
          task['section_gid'] = section['gid']
          incomplete_tasks << task
        end
      else
        # If we get an error fetching tasks, return the error
        return incomplete_result
      end
      
      # Fetch completed tasks from last 14 days
      completed_result = fetch_section_tasks(section['gid'], include_completed: true, completed_since: cutoff_date)
      if completed_result[:success]
        completed_result[:tasks].each do |task|
          next unless task['completed'] == true
          completed_at = task['completed_at'] ? Time.parse(task['completed_at']) : nil
          if completed_at && completed_at >= cutoff_date
            task['section_gid'] = section['gid']
            completed_tasks << task
          end
        end
      else
        # If we get an error fetching completed tasks, return the error
        return completed_result
      end
    end
    
    { success: true, incomplete: incomplete_tasks, completed: completed_tasks }
  end

  def fetch_task_details(task_gid)
    return { success: false, error: 'not_authenticated', message: 'Not authenticated with Asana' } unless authenticated?
    
    begin
      response = HTTP.auth("Bearer #{access_token}")
                      .get("https://app.asana.com/api/1.0/tasks/#{task_gid}", params: {
                        opt_fields: 'name,completed,assignee.name,assignee.gid,due_on,gid,completed_at,notes,html_notes,created_at,tags.name,tags.color,tags.gid,parent,projects,workspace,permalink_url'
                      })
      
      result = handle_api_response(response, 'fetch_task_details')
      
      # If token was refreshed, retry the request
      if result[:error] == 'retry'
        response = HTTP.auth("Bearer #{access_token}")
                        .get("https://app.asana.com/api/1.0/tasks/#{task_gid}", params: {
                          opt_fields: 'name,completed,assignee.name,assignee.gid,due_on,gid,completed_at,notes,html_notes,created_at,tags.name,tags.color,tags.gid,parent,projects,workspace,permalink_url'
                        })
        result = handle_api_response(response, 'fetch_task_details')
      end
      
      if result[:success]
        { success: true, task: result[:data]['data'] }
      else
        result
      end
    rescue => e
      Rails.logger.error "Asana fetch_task_details error: #{e.message}"
      { success: false, error: 'network_error', message: "Failed to connect to Asana: #{e.message}" }
    end
  end

  def format_for_cache(sections, tasks)
    formatted_sections = sections.map.with_index do |section, index|
      {
        'gid' => section['gid'],
        'name' => section['name'] || 'Unnamed Section',
        'position' => index
      }
    end

    formatted_tasks = tasks.map.with_index do |task, index|
      {
        'gid' => task['gid'],
        'name' => task['name'] || 'Unnamed Task',
        'section_gid' => task['section_gid'],
        'position' => index,
        'completed' => task['completed'] == true,
        'completed_at' => task['completed_at'],
        'due_on' => task['due_on'],
        'assignee' => task['assignee'] ? { 'gid' => task['assignee']['gid'], 'name' => task['assignee']['name'] } : nil,
        'created_at' => task['created_at'],
        'tags' => task['tags']&.map { |tag| { 'gid' => tag['gid'], 'name' => tag['name'], 'color' => tag['color'] } }
      }
    end

    { sections: formatted_sections, tasks: formatted_tasks }
  end

  private

  def handle_api_response(response, operation = 'API call')
    case response.status
    when 200
      { success: true, data: JSON.parse(response.body.to_s) }
    when 401
      # Try token refresh if available
      if refresh_access_token
        { success: false, error: 'retry', message: 'Token refreshed, please retry' }
      else
        error_data = begin
          JSON.parse(response.body.to_s)
        rescue
          {}
        end
        error_msg = error_data.dig('errors', 0, 'message') || 'Asana token expired. Please reconnect your account.'
        { success: false, error: 'token_expired', message: error_msg }
      end
    when 403
      error_data = begin
        JSON.parse(response.body.to_s)
      rescue
        {}
      end
      error_msg = error_data.dig('errors', 0, 'message') || 'You do not have permission to access this resource.'
      { success: false, error: 'permission_denied', message: error_msg }
    when 404
      error_data = begin
        JSON.parse(response.body.to_s)
      rescue
        {}
      end
      error_msg = error_data.dig('errors', 0, 'message') || 'Resource not found in Asana.'
      { success: false, error: 'not_found', message: error_msg }
    else
      error_data = begin
        JSON.parse(response.body.to_s)
      rescue
        {}
      end
      error_msg = error_data.dig('errors', 0, 'message') || "Asana API error: #{response.status}"
      { success: false, error: 'api_error', message: error_msg }
    end
  rescue => e
    Rails.logger.error "Asana #{operation} error: #{e.message}"
    { success: false, error: 'network_error', message: "Failed to connect to Asana: #{e.message}" }
  end

  def self.task_url(task_gid, project_id = nil)
    if project_id
      "https://app.asana.com/0/#{project_id}/#{task_gid}"
    else
      "https://app.asana.com/0/0/#{task_gid}"
    end
  end
end
