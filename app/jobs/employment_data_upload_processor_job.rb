class EmploymentDataUploadProcessorJob < ApplicationJob
  queue_as :default

  def perform(upload_event_id, organization_id)
    upload_event = UploadEvent.find(upload_event_id)
    organization = Organization.find(organization_id)
    
    processor = EmploymentDataUploadProcessor.new(upload_event, organization)
    
    result = processor.process
    
    if result
      # Upload processed successfully
      # Could add notification logic here
      Rails.logger.info "Upload #{upload_event_id} processed successfully"
      return true
    else
      # Upload processing failed
      Rails.logger.error "Upload #{upload_event_id} processing failed"
      return false
    end
  rescue => e
    # Handle any errors during processing
    Rails.logger.error "Error processing upload #{upload_event_id}: #{e.message}"
    upload_event&.mark_as_failed!(e.message)
    return false
  end
end
