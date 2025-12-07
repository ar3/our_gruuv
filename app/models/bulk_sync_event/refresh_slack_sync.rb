class BulkSyncEvent::RefreshSlackSync < BulkSyncEvent
  def validate_file_type(file)
    # No file validation needed for sync operations
    true
  end

  def process_file_for_preview
    # Alias for generate_preview
    generate_preview
  end

  def generate_preview
    parser = RefreshSlackSyncParser.new(organization)
    
    if parser.parse
      # Store the raw Slack API response in source_contents
      self.source_contents = parser.raw_slack_response.to_json
      
      # Store metadata in source_data
      self.source_data = {
        type: 'slack_sync',
        workspace_id: parser.workspace_id,
        workspace_name: parser.workspace_name,
        total_users_fetched: parser.total_users_fetched,
        fetched_at: Time.current.iso8601
      }
      
      update!(
        source_contents: self.source_contents,
        source_data: self.source_data,
        preview_actions: parser.enhanced_preview_actions,
        attempted_at: Time.current
      )
      parser
    else
      @parser = parser
      false
    end
  end

  def process_upload_in_background
    RefreshSlackSyncProcessorJob.perform_later(id, organization.id)
  end

  def display_name
    'Refresh Slack Identities'
  end

  def file_extension
    nil
  end

  def parse_error_message
    return "Sync failed: Unable to generate preview." unless @parser
    "Sync failed: #{@parser.errors.join(', ')}"
  end

  def source_type
    'slack_sync'
  end
end

