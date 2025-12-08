class AsanaUrlParser
  # Extract project ID from various Asana URL patterns
  # Supported patterns:
  # 1. https://app.asana.com/0/{project_id}/{section_id}
  # 2. https://app.asana.com/0/{project_id}
  # 3. https://app.asana.com/{workspace_id}/project/{project_id}/...
  # 4. https://app.asana.com/{workspace_id}/project/{project_id}/list/{list_id}
  def self.extract_project_id(url)
    return nil unless url.present?
    
    # Only process Asana URLs
    return nil unless url.include?('asana.com')
    
    # Try pattern 3/4 first (most common): /project/{project_id}
    match = url.match(%r{/project/(\d+)})
    return match[1] if match
    
    # Try pattern 1/2: /0/{project_id}
    match = url.match(%r{app\.asana\.com/0/(\d+)})
    return match[1] if match
    
    nil
  end
end

