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
    return [] unless authenticated?
    
    begin
      response = HTTP.auth("Bearer #{access_token}")
                      .get("https://app.asana.com/api/1.0/projects/#{project_id}/sections")
      
      data = JSON.parse(response.body.to_s)
      data['data'] || []
    rescue => e
      Rails.logger.error "Asana API error: #{e.message}"
      []
    end
  end

  def fetch_section_tasks(section_id)
    return [] unless authenticated?
    
    begin
      response = HTTP.auth("Bearer #{access_token}")
                      .get("https://app.asana.com/api/1.0/sections/#{section_id}/tasks", params: {
                        opt_fields: 'name,completed,assignee,due_on,gid',
                        completed_since: 'now' # Only incomplete tasks
                      })
      
      data = JSON.parse(response.body.to_s)
      data['data'] || []
    rescue => e
      Rails.logger.error "Asana API error: #{e.message}"
      []
    end
  end

  def self.task_url(task_gid, project_id = nil)
    if project_id
      "https://app.asana.com/0/#{project_id}/#{task_gid}"
    else
      "https://app.asana.com/0/0/#{task_gid}"
    end
  end
end
