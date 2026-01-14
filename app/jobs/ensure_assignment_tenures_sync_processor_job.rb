class EnsureAssignmentTenuresSyncProcessorJob < ApplicationJob
  queue_as :default

  def perform(bulk_sync_event_id, organization_id)
    bulk_sync_event = BulkSyncEvent.find(bulk_sync_event_id)
    organization = Organization.find(organization_id)

    # Mark as processing
    bulk_sync_event.mark_as_processing!

    # Process the sync
    processor = EnsureAssignmentTenuresSyncProcessor.new(bulk_sync_event, organization)
    
    if processor.process
      # Mark as completed with results
      bulk_sync_event.mark_as_completed!(processor.results)
      true
    else
      # Mark as failed
      error_message = "Processing failed: #{processor.results[:failures].map { |f| f[:error] }.join(', ')}"
      bulk_sync_event.mark_as_failed!(error_message)
      false
    end
  rescue ActiveRecord::RecordNotFound => e
    # Re-raise RecordNotFound errors
    raise e
  rescue => e
    # Mark as failed with error details
    error_message = "Unexpected error: #{e.message}"
    if bulk_sync_event
      bulk_sync_event.reload
      bulk_sync_event.mark_as_failed!(error_message)
    end
    
    # Log the error for debugging
    Rails.logger.error "EnsureAssignmentTenuresSyncProcessorJob failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    false
  end

  # Class method to perform and get result immediately (for inline processing)
  def self.perform_and_get_result(bulk_sync_event_id, organization_id)
    job = new
    job.perform(bulk_sync_event_id, organization_id)
  end
end
