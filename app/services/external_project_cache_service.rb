class ExternalProjectCacheService
  def self.sync_project(cacheable, source, teammate)
    return { success: false, error: 'Invalid source' } unless %w[asana jira linear].include?(source)
    
    # Get the appropriate service
    service = get_service_for_source(source, teammate)
    return { success: false, error: 'Service not authenticated' } unless service&.authenticated?
    
    # Get project ID from cacheable
    project_id = get_project_id(cacheable, source)
    return { success: false, error: 'Project ID not found' } unless project_id.present?
    
    # Fetch and cache
    fetch_and_cache(service, project_id, cacheable, source, teammate)
  end

  def self.fetch_and_cache(service, project_id, cacheable, source, teammate)
    begin
      # Fetch data based on source
      if source == 'asana'
        sections_result = service.fetch_project_sections(project_id)
        unless sections_result[:success]
          return { 
            success: false, 
            error: sections_result[:message] || sections_result[:error], 
            error_type: sections_result[:error] || 'unknown_error' 
          }
        end
        
        sections = sections_result[:sections]
        
        task_data_result = service.fetch_all_project_tasks(project_id)
        unless task_data_result[:success]
          return { 
            success: false, 
            error: task_data_result[:message] || task_data_result[:error], 
            error_type: task_data_result[:error] || 'unknown_error' 
          }
        end
        
        incomplete_tasks = task_data_result[:incomplete] || []
        completed_tasks = task_data_result[:completed] || []
      else
        # Future: Add Jira/Linear support
        return { success: false, error: 'Source not yet supported', error_type: 'unsupported_source' }
      end
      
      # Limit to 200 items
      limited_data = limit_items_to_200(incomplete_tasks, completed_tasks)
      
      # Format for cache
      formatted = service.format_for_cache(sections, limited_data[:items])
      
      # Create or update cache
      cache = ExternalProjectCache.find_or_initialize_by(
        cacheable: cacheable,
        source: source
      )
      
      cache.assign_attributes(
        external_project_id: project_id,
        external_project_url: get_project_url(cacheable, source),
        sections_data: formatted[:sections],
        items_data: formatted[:tasks],
        has_more_items: limited_data[:has_more],
        last_synced_at: Time.current,
        last_synced_by_teammate: teammate
      )
      
      if cache.save
        { success: true, cache: cache }
      else
        { success: false, error: cache.errors.full_messages.join(', '), error_type: 'validation_error' }
      end
    rescue => e
      Rails.logger.error "ExternalProjectCacheService error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message, error_type: 'exception' }
    end
  end

  def self.limit_items_to_200(incomplete_items, completed_items)
    total_count = incomplete_items.length + completed_items.length
    
    # Sort incomplete by due date (nulls last), then by name
    sorted_incomplete = incomplete_items.sort_by do |item|
      [item['due_on'] ? 0 : 1, item['due_on'] || '', item['name'] || '']
    end
    
    # Sort completed by completed_at desc (most recent first)
    sorted_completed = completed_items.sort_by do |item|
      completed_at = item['completed_at'] ? Time.parse(item['completed_at']) : Time.at(0)
      [-completed_at.to_i, item['name'] || '']
    end
    
    # Take first 200 total, prioritizing incomplete
    all_items = sorted_incomplete + sorted_completed
    limited_items = all_items.take(200)
    
    {
      items: limited_items,
      has_more: total_count > 200,
      total_count: total_count,
      incomplete_count: incomplete_items.length,
      completed_count: completed_items.length
    }
  end

  def self.format_sections_for_cache(sections)
    sections.map.with_index do |section, index|
      {
        'gid' => section['gid'],
        'name' => section['name'] || 'Unnamed Section',
        'position' => index
      }
    end
  end

  def self.format_items_for_cache(items)
    items.map.with_index do |item, index|
      {
        'gid' => item['gid'],
        'name' => item['name'] || 'Unnamed Item',
        'section_gid' => item['section_gid'],
        'position' => index,
        'completed' => item['completed'] == true,
        'completed_at' => item['completed_at'],
        'due_on' => item['due_on'],
        'assignee' => item['assignee'] ? { 'gid' => item['assignee']['gid'], 'name' => item['assignee']['name'] } : nil,
        'created_at' => item['created_at'],
        'tags' => item['tags']&.map { |tag| { 'gid' => tag['gid'], 'name' => tag['name'], 'color' => tag['color'] } }
      }
    end
  end

  private

  def self.get_service_for_source(source, teammate)
    case source
    when 'asana'
      AsanaService.new(teammate)
    when 'jira'
      # Future: JiraService.new(teammate)
      nil
    when 'linear'
      # Future: LinearService.new(teammate)
      nil
    else
      nil
    end
  end

  def self.get_project_id(cacheable, source)
    case cacheable
    when OneOnOneLink
      if source == 'asana'
        cacheable.asana_project_id || ExternalProjectUrlParser.extract_project_id(cacheable.url, source)
      else
        ExternalProjectUrlParser.extract_project_id(cacheable.url, source)
      end
    when TeamAsanaLink
      if source == 'asana'
        cacheable.asana_project_id || ExternalProjectUrlParser.extract_project_id(cacheable.url, source)
      else
        ExternalProjectUrlParser.extract_project_id(cacheable.url, source)
      end
    else
      # Future: Handle Huddle and Goal
      nil
    end
  end

  def self.get_project_url(cacheable, source)
    case cacheable
    when OneOnOneLink
      cacheable.url
    when TeamAsanaLink
      cacheable.url
    else
      # Future: Handle Huddle and Goal
      nil
    end
  end
end

