class UnassignedEmployeeUploadProcessorJob < ApplicationJob
  queue_as :default

  def perform(upload_event_id, organization_id)
    upload_event = UploadEvent.find(upload_event_id)
    organization = Organization.find(organization_id)

    # Mark as processing
    upload_event.mark_as_processing!

    # Process the upload
    processor = UnassignedEmployeeUploadProcessor.new(upload_event, organization)
    
    if processor.process
      # Mark as completed with results
      upload_event.mark_as_completed!(processor.results)
    else
      # Mark as failed
      error_message = "Processing failed: #{processor.parser.errors.join(', ')}"
      upload_event.mark_as_failed!(error_message)
    end
  rescue => e
    # Mark as failed with error details
    error_message = "Unexpected error: #{e.message}"
    upload_event.reload
    upload_event.mark_as_failed!(error_message)
    
    # Log the error for debugging
    Rails.logger.error "UnassignedEmployeeUploadProcessorJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end
