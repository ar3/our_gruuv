class UploadEvent::UploadAssignmentCheckins < UploadEvent
  def validate_file_type(file)
    file.content_type.in?(['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/vnd.ms-excel'])
  end

  def process_file_for_preview
    parser = EmploymentDataUploadParser.new(file_content)
    
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
    EmploymentDataUploadProcessorJob.perform_later(id, organization.id)
  end

  def display_name
    'Upload Assignment Check-Ins'
  end

  def file_extension
    'xlsx'
  end

  def parse_error_message(parser)
    "Upload failed: #{parser.errors.join(', ')}"
  end

  def process_file_content_for_storage(file)
    binary_content = file.read
    Base64.strict_encode64(binary_content)
  end
end




