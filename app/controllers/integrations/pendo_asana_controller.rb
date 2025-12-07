class Integrations::PendoAsanaController < ApplicationController
  
  def index
    # Handle form submissions
    if params[:test_pendo].present?
      test_pendo_connection
    elsif params[:test_asana].present?
      test_asana_connection
    elsif params[:sync_guides].present?
      sync_guides
    end
  end

  def test_pendo_connection
    api_key = params[:pendo_api_key]
    
    if api_key.blank?
      flash[:alert] = "Pendo API key is required"
      redirect_to integrations_pendo_asana_index_path(pendo_api_key: api_key, asana_api_key: params[:asana_api_key])
      return
    end

    begin
      service = PendoService.new(api_key)
      success = service.test_connection
      
      if success
        # Fetch a limited number of guides for testing (max 50)
        guides = service.fetch_guides(limit: 50, active_only: true)
        flash[:notice] = "Pendo connection successful! Found #{guides.count} guides."
        # Store guide data in session for display
        @pendo_guides = guides
        @pendo_guide_count = guides.count
      else
        flash[:alert] = "Pendo connection failed"
      end
    rescue => e
      flash[:alert] = "Pendo connection error: #{e.message}"
    end
    
    redirect_to integrations_pendo_asana_index_path(pendo_api_key: api_key, asana_api_key: params[:asana_api_key])
  end

  def test_asana_connection
    api_key = params[:asana_api_key]
    project_id = params[:project_id]
    
    if api_key.blank?
      flash[:alert] = "Asana API key is required"
      redirect_to integrations_pendo_asana_index_path(pendo_api_key: params[:pendo_api_key], asana_api_key: api_key, project_id: project_id)
      return
    end

    if project_id.blank?
      flash[:alert] = "Asana Project ID is required"
      redirect_to integrations_pendo_asana_index_path(pendo_api_key: params[:pendo_api_key], asana_api_key: api_key, project_id: project_id)
      return
    end

    begin
      service = AsanaService.new(api_key)
      success = service.test_connection
      
      if success
        # Get project details to verify it exists and get the name
        response = HTTP.headers(authorization: "Bearer #{api_key}")
                       .get("https://app.asana.com/api/1.0/projects/#{project_id}")
        
        if response.status == 200
          project_data = JSON.parse(response.body.to_s)["data"]
          project_name = project_data["name"]
          flash[:notice] = "Asana connection successful! Project: #{project_name}"
          session[:asana_project] = { id: project_id, name: project_name }
          session[:asana_project_name] = project_name
        else
          flash[:alert] = "Asana connection successful, but project ID #{project_id} not found"
        end
      else
        flash[:alert] = "Asana connection failed"
      end
    rescue => e
      flash[:alert] = "Asana connection error: #{e.message}"
    end
    
    redirect_to integrations_pendo_asana_index_path(pendo_api_key: params[:pendo_api_key], asana_api_key: api_key, project_id: project_id)
  end

  def fetch_asana_projects
    api_key = params[:asana_api_key]
    
    if api_key.blank?
      render json: { success: false, message: "Asana API key is required" }
      return
    end

    begin
      service = AsanaService.new(api_key)
      projects = service.fetch_projects
      
      render json: { 
        success: true, 
        projects: projects.map { |p| { id: p["gid"], name: p["name"] } }
      }
    rescue => e
      render json: { success: false, message: "Failed to fetch projects: #{e.message}" }
    end
  end

  def sync_guides
    pendo_api_key = params[:pendo_api_key]
    asana_api_key = params[:asana_api_key]
    project_id = params[:project_id]
    limit = params[:sync_limit].to_i
    
    if pendo_api_key.blank? || asana_api_key.blank? || project_id.blank?
      flash[:alert] = "All fields are required"
      redirect_to integrations_pendo_asana_index_path(pendo_api_key: pendo_api_key, asana_api_key: asana_api_key, project_id: project_id, sync_limit: limit)
      return
    end

    # begin
      pendo_service = PendoService.new(pendo_api_key)
      asana_service = AsanaService.new(asana_api_key)
      
      # Fetch guides with the specified limit
      guides = pendo_service.fetch_guides(limit: limit, active_only: true)
      
      # Debug: Fetch custom fields for the project
      puts "DEBUG: Fetching custom fields for project #{project_id}"
      asana_service.fetch_project_custom_fields(project_id)
      
      results = []
      counter = 0
      guides.each do |guide|
        
        if guide["state"] == "disabled"
          next
        end
        # counter += 1
        # if counter >= 100
        #   flash[:notice] = "LIMITED Synchronization completed successfully! Processed #{counter} of #{guides.count} guides."
        #   return redirect_to integrations_pendo_asana_index_path(pendo_api_key: pendo_api_key, asana_api_key: asana_api_key, project_id: project_id)
        # end

        # Only sync active guides
        # next unless guide["state"] == "active"
        
        guide_id = guide["id"]
        guide_name = guide["name"] || "Untitled Guide"
        
        puts "DEBUG: Processing guide #{counter}: #{guide_name} (ID: #{guide_id})"
        
        # Create rich description with all the requested information
        description = build_guide_description(guide)
        
        # Create task name with guide ID for identification
        task_name = "#{guide_name}"
        
        puts "DEBUG: Task name: #{task_name}"
        puts "DEBUG: Looking for existing task with pendo_guide_id: #{guide_id}"
        
        # Look for existing task by pendo_guide_id custom field
        existing_task = asana_service.find_task_by_custom_field(project_id, "1211379876943823", guide_id)
        
        # Prepare custom fields with sync time and status
        current_time = Time.current.iso8601
        custom_fields = {
          "1211379876943823" => guide_id,           # pendo_guide_id
          "1211414861234325" => current_time,       # pendo_last_synced
          "1211414861234327" => guide["state"]      # pendo_status
        }
        
        if existing_task
          puts "DEBUG: Found existing task: #{existing_task['gid']}"
          # Update existing task
          updated_task = asana_service.update_task(existing_task["gid"], task_name, description, custom_fields)
          results << { guide_id: guide_id, action: "updated", task_id: updated_task["gid"] }
          puts "DEBUG: Successfully updated task: #{updated_task['gid']}"
        else
          puts "DEBUG: No existing task found, creating new one"
          # Create new task
          new_task = asana_service.create_task(project_id, task_name, description, custom_fields)
          results << { guide_id: guide_id, action: "created", task_id: new_task["gid"] }
          puts "DEBUG: Successfully created task: #{new_task['gid']}"
        end
      end
      
      # Store results in session for display
      session[:sync_results] = results
      flash[:notice] = "Synchronization completed successfully! Processed #{results.count} of #{guides.count} guides."
    # rescue => e
    #   flash[:alert] = "Synchronization failed: #{e.message}"
    # end
    
    redirect_to integrations_pendo_asana_index_path(pendo_api_key: pendo_api_key, asana_api_key: asana_api_key, project_id: project_id)
  end

  private

  def build_guide_description(guide)
    # Helper method to format timestamps
    format_timestamp = ->(timestamp) {
      return "Never" if timestamp.nil? || timestamp == 0
      Time.at(timestamp / 1000).strftime("%B %d, %Y at %I:%M %p")
    }

    # Extract user information
    created_by = guide["createdByUser"]
    created_by_name = created_by ? "#{created_by['first']} #{created_by['last']}".strip : created_by["username"]
    created_by_name = created_by["username"] if created_by_name.empty?

    last_updated_by = guide["lastUpdatedByUser"]
    last_updated_by_name = last_updated_by ? "#{last_updated_by['first']} #{last_updated_by['last']}".strip : last_updated_by["username"]
    last_updated_by_name = last_updated_by["username"] if last_updated_by_name.empty?

    # Build the description
    description = []
    description << "**Guide Information:**"
    description << ""
    description << "• **Link to Guide:** https://app.pendo.io/guide/#{guide['id']}"
    description << "• **Guide Name:** #{guide['name']}"
    description << "• **Status:** #{guide['state']}"
    description << "• **Created by:** #{created_by_name} on #{format_timestamp.call(guide['createdAt'])}"
    description << "• **Last updated by:** #{last_updated_by_name} on #{format_timestamp.call(guide['lastUpdatedAt'])}"
    description << "• **Launch Method:** #{guide['launchMethod']}"
    description << ""
    
    # Publication status
    if guide['publishedEver']
      description << "• **Published:** Yes, on #{format_timestamp.call(guide['publishedAt'])}"
    else
      description << "• **Published:** No, never published"
    end
    
    description << ""
    description << "**Guide Details:**"
    description << "• **State:** #{guide['state']}"
    description << "• **Kind:** #{guide['kind']}"
    description << "• **Multi-step:** #{guide['isMultiStep'] ? 'Yes' : 'No'}"
    description << "• **Training Guide:** #{guide['isTraining'] ? 'Yes' : 'No'}"
    
    # Add audience information if available
    if guide['audienceUiHint'] && guide['audienceUiHint']['filters']
      description << ""
      description << "**Target Audience:**"
      guide['audienceUiHint']['filters'].each do |filter|
        if filter['name']
          description << "• #{filter['name']}: #{filter['operator']} #{filter['value']}"
        end
      end
    end
    
    description << "\n\n\n• **Last Synced via OG:** #{Time.current.iso8601}"
    description.join("\n")
  end
end
