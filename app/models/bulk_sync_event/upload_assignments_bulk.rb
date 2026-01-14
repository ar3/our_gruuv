class BulkSyncEvent::UploadAssignmentsBulk < BulkSyncEvent
  def validate_file_type(file)
    file.content_type.in?(['text/csv', 'application/csv']) || file.original_filename.end_with?('.csv')
  end

  def process_file_for_preview
    parser = AssignmentsBulkUploadParser.new(source_contents, organization)
    
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
    AssignmentsBulkUploadProcessorJob.perform_and_get_result(id, organization.id)
  end

  def display_name
    'Upload Assignments (Bulk)'
  end

  def file_extension
    'csv'
  end

  def parse_error_message
    return "Upload failed: Please check your file format." unless @parser
    "Upload failed: #{@parser.errors.join(', ')}"
  end

  def process_file_content_for_storage(file)
    file.read
  end
end
