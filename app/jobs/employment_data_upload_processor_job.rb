class EmploymentDataUploadProcessorJob < ApplicationJob
  queue_as :default

  def perform(bulk_sync_event_id, organization_id)
    bulk_sync_event = BulkSyncEvent.find(bulk_sync_event_id)
    organization = Organization.find(organization_id)
    
    # Mark as processing
    bulk_sync_event.mark_as_processing!
    
    processor = EmploymentDataUploadProcessor.new(bulk_sync_event, organization)
    
    result = processor.process
    
    if result
      # Upload processed successfully
      bulk_sync_event.mark_as_completed!(processor.results)
      Rails.logger.info "Bulk sync event #{bulk_sync_event_id} processed successfully"
      return true
    else
      # Upload processing failed
      error_message = "Processing failed: #{processor.results[:failures].map { |f| f[:error] }.join(', ')}"
      bulk_sync_event.mark_as_failed!(error_message)
      Rails.logger.error "Bulk sync event #{bulk_sync_event_id} processing failed"
      return false
    end
  rescue => e
    # Handle any errors during processing
    Rails.logger.error "Error processing bulk sync event #{bulk_sync_event_id}: #{e.message}"
    bulk_sync_event&.mark_as_failed!(e.message)
    return false
  end

  def self.perform_and_get_result(bulk_sync_event_id, organization_id)
    job = new
    job.perform(bulk_sync_event_id, organization_id)
  end
end
