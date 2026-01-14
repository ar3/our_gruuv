class BulkSyncEvent::EnsureAssignmentTenuresSync < BulkSyncEvent
  def validate_file_type(file)
    # No file validation needed for sync operations
    true
  end

  def process_file_for_preview
    # Alias for generate_preview
    generate_preview
  end

  def generate_preview
    parser = EnsureAssignmentTenuresSyncParser.new(organization)
    
    if parser.parse
      update!(
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
    EnsureAssignmentTenuresSyncProcessorJob.perform_and_get_result(id, organization.id)
  end

  def display_name
    'Ensure Assignment Tenures'
  end

  def file_extension
    nil
  end

  def parse_error_message
    return "Sync failed: Unable to generate preview." unless @parser
    "Sync failed: #{@parser.errors.join(', ')}"
  end

  def source_type
    'database_sync'
  end
end
