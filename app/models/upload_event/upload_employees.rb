class UploadEvent::UploadEmployees < UploadEvent
  def validate_file_type(file)
    file.content_type.in?(['text/csv', 'application/csv']) || file.original_filename.end_with?('.csv')
  end

  def process_file_for_preview
    parser = UnassignedEmployeeUploadParser.new(file_content)
    
    if parser.parse
      update!(
        preview_actions: parser.enhanced_preview_actions,
        attempted_at: Time.current
      )
      true
    else
      false
    end
  end

  def process_upload_in_background
    UnassignedEmployeeUploadProcessorJob.perform_later(id, organization.id)
  end

  def display_name
    'Upload Employee Positions'
  end

  def file_extension
    'csv'
  end

  def parse_error_message(parser)
    "Upload failed: #{parser.errors.join(', ')}"
  end

  def process_file_content_for_storage(file)
    file.read
  end
end




