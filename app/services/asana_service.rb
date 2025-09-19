class AsanaService
  def initialize(api_key)
    @api_key = api_key
  end

  def test_connection
    # Simple API call to test connection
    response = HTTP.headers(authorization: "Bearer #{@api_key}")
                   .get("https://app.asana.com/api/1.0/users/me")
    
    response.status == 200
  end

  def fetch_projects
    response = HTTP.headers(authorization: "Bearer #{@api_key}")
                   .get("https://app.asana.com/api/1.0/projects")
    
    raise "Failed to fetch projects: #{response.status}" unless response.status == 200
    
    JSON.parse(response.body.to_s)["data"] || []
  end

  def fetch_tasks_for_project(project_id)
    puts "DEBUG: Fetching tasks for project #{project_id}"
    response = HTTP.headers(authorization: "Bearer #{@api_key}")
                   .get("https://app.asana.com/api/1.0/projects/#{project_id}/tasks")
    
    puts "DEBUG: Fetch tasks response status: #{response.status}"
    puts "DEBUG: Fetch tasks response body: #{response.body.to_s[0..500]}..." if response.body.to_s.length > 500
    
    raise "Failed to fetch tasks: #{response.status}" unless response.status == 200
    
    tasks = JSON.parse(response.body.to_s)["data"] || []
    puts "DEBUG: Found #{tasks.count} tasks in project"
    tasks
  end

  def create_task(project_id, name, notes = nil, custom_fields = {})
    task_data = {
      name: name,
      projects: [project_id]
    }
    task_data[:notes] = notes if notes.present?
    task_data[:custom_fields] = custom_fields if custom_fields.any?

    puts "DEBUG: Creating task with data: #{task_data.inspect}"
    
    response = HTTP.headers(authorization: "Bearer #{@api_key}")
                   .post("https://app.asana.com/api/1.0/tasks", json: { data: task_data })
    
    puts "DEBUG: Create task response status: #{response.status}"
    puts "DEBUG: Create task response body: #{response.body.to_s}"
    
    raise "Failed to create task: #{response.status}" unless response.status == 201
    
    JSON.parse(response.body.to_s)["data"]
  end

  def update_task(task_id, name, notes = nil, custom_fields = {})
    task_data = { name: name }
    task_data[:notes] = notes if notes.present?
    task_data[:custom_fields] = custom_fields if custom_fields.any?

    puts "DEBUG: Updating task #{task_id} with data: #{task_data.inspect}"
    
    response = HTTP.headers(authorization: "Bearer #{@api_key}")
                   .put("https://app.asana.com/api/1.0/tasks/#{task_id}", json: { data: task_data })
    
    puts "DEBUG: Update task response status: #{response.status}"
    puts "DEBUG: Update task response body: #{response.body.to_s}"
    
    raise "Failed to update task: #{response.status}" unless response.status == 200
    
    JSON.parse(response.body.to_s)["data"]
  end

  def find_task_by_custom_field(project_id, custom_field_name, custom_field_value)
    puts "DEBUG: Looking for task with custom field '#{custom_field_name}' = '#{custom_field_value}'"
    
    # Get workspace GID from project
    workspace_gid = get_workspace_gid_from_project(project_id)
    puts "DEBUG: Workspace GID: #{workspace_gid}"
    
    if workspace_gid
      # Use Asana's search endpoint with proper format
      url = "https://app.asana.com/api/1.0/workspaces/#{workspace_gid}/tasks/search"
      query_string = "custom_fields.#{custom_field_name}.value=#{custom_field_value}&opt_fields=name,custom_fields"
      full_url = "#{url}?#{query_string}"
      
      puts "DEBUG: Searching with URL: #{full_url}"
      
      response = HTTP.headers(authorization: "Bearer #{@api_key}")
                     .get(full_url)
      
      puts "DEBUG: Search response status: #{response.status}"
      puts "DEBUG: Search response body: #{response.body.to_s}"
      
      if response.status == 200
        search_results = JSON.parse(response.body.to_s)["data"] || []
        found_task = search_results.first # Should only be one match
        puts "DEBUG: Found task via search: #{found_task ? found_task['gid'] : 'None'}"
        return found_task
      else
        puts "DEBUG: Search failed: #{response.status} - #{response.body.to_s}"
      end
    end
    raise "Search failed: #{response.status} - #{response.body.to_s}"
    # Fallback to manual search if search API fails
    puts "DEBUG: Falling back to manual search"
    tasks = fetch_tasks_for_project(project_id)
    puts "DEBUG: Searching through #{tasks.count} tasks for custom field '#{custom_field_name}' = '#{custom_field_value}'"
    
    found_task = tasks.find { |task| task["custom_fields"] && task["custom_fields"][custom_field_name] == custom_field_value }
    puts "DEBUG: Found task (fallback): #{found_task ? found_task['gid'] : 'None'}"
    found_task
  end

  def get_workspace_gid_from_project(project_id)
    puts "DEBUG: Getting workspace GID for project #{project_id}"
    response = HTTP.headers(authorization: "Bearer #{@api_key}")
                   .get("https://app.asana.com/api/1.0/projects/#{project_id}")
    
    if response.status == 200
      project_data = JSON.parse(response.body.to_s)["data"]
      workspace_gid = project_data["workspace"]["gid"]
      puts "DEBUG: Project workspace GID: #{workspace_gid}"
      workspace_gid
    else
      puts "DEBUG: Failed to get project data: #{response.status} - #{response.body.to_s}"
      nil
    end
  end

  def fetch_project_custom_fields(project_id)
    puts "DEBUG: Fetching custom fields for project #{project_id}"
    response = HTTP.headers(authorization: "Bearer #{@api_key}")
                   .get("https://app.asana.com/api/1.0/projects/#{project_id}")
    
    puts "DEBUG: Project response status: #{response.status}"
    
    if response.status == 200
      project_data = JSON.parse(response.body.to_s)["data"]
      custom_fields = project_data["custom_field_settings"] || []
      puts "DEBUG: Found #{custom_fields.count} custom fields:"
      custom_fields.each do |field|
        puts "DEBUG: Custom Field - Name: '#{field['custom_field']['name']}', ID: '#{field['custom_field']['gid']}'"
      end
      custom_fields
    else
      puts "DEBUG: Failed to fetch project: #{response.status} - #{response.body.to_s}"
      []
    end
  end
end

