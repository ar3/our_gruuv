class AssignmentsBulkUploadProcessorJob < ApplicationJob
  queue_as :default

  def perform(bulk_sync_event_id, organization_id)
    Rails.logger.info "❌❌❌ AssignmentsBulkUploadProcessorJob: Starting job for bulk_sync_event #{bulk_sync_event_id}, organization #{organization_id}"
    
    begin
      bulk_sync_event = BulkSyncEvent.find(bulk_sync_event_id)
      organization = Organization.find(organization_id)
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessorJob: Record not found - #{e.message}"
      raise e
    end
    
    Rails.logger.info "❌❌❌ AssignmentsBulkUploadProcessorJob: Found bulk_sync_event #{bulk_sync_event.id} (type: #{bulk_sync_event.type}, status: #{bulk_sync_event.status})"
    Rails.logger.info "❌❌❌ AssignmentsBulkUploadProcessorJob: Organization: #{organization.name} (id: #{organization.id})"
    
    # Note: processor.process will mark as processing after checking can_process?
    processor = AssignmentsBulkUploadProcessor.new(bulk_sync_event, organization)
    
    begin
      result = processor.process
    rescue => e
      # Exception was raised during processing - use the exception message
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessorJob: Exception during processor.process: #{e.class.name} - #{e.message}"
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessorJob: Backtrace: #{e.backtrace.first(15).join("\n")}"
      
      # Get error message from processor's last_error or exception
      error_source = processor.last_error || e
      error_message = if error_source.is_a?(Exception)
        "#{error_source.class.name}: #{error_source.message}"
      else
        error_source.to_s
      end
      
      # Add to failures if not already there
      unless processor.results[:failures].any? { |f| f[:error]&.include?(error_message) }
        processor.results[:failures] << {
          type: 'system_error',
          error: error_message,
          backtrace: error_source.respond_to?(:backtrace) ? error_source.backtrace&.first(5) : nil
        }
      end
      
      bulk_sync_event.mark_as_failed!(error_message)
      raise e
    end
    
    if result
      # Upload processed successfully
      bulk_sync_event.mark_as_completed!(processor.results)
      Rails.logger.info "❌❌❌ AssignmentsBulkUploadProcessorJob: Bulk sync event #{bulk_sync_event_id} processed successfully"
      Rails.logger.info "❌❌❌ AssignmentsBulkUploadProcessorJob: Results - Successes: #{processor.results[:successes].length}, Failures: #{processor.results[:failures].length}"
      return true
    else
      # Upload processing failed - check for failures or last_error
      failure_messages = processor.results[:failures].map { |f| f[:error] }.compact
      
      error_message = if failure_messages.any?
        "Processing failed: #{failure_messages.join(', ')}"
      elsif processor.last_error
        error_source = processor.last_error
        if error_source.is_a?(Exception)
          "#{error_source.class.name}: #{error_source.message}"
        else
          error_source.to_s
        end
      else
        "Processing failed: Processor returned false but no error details were captured. Please check the logs for more information."
      end
      
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessorJob: Processing returned false. Error message: #{error_message}"
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessorJob: Failures: #{processor.results[:failures].inspect}"
      Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessorJob: Last error: #{processor.last_error.inspect}" if processor.last_error
      bulk_sync_event.mark_as_failed!(error_message)
      raise RuntimeError, error_message
    end
  rescue ActiveRecord::RecordNotFound => e
    # Re-raise RecordNotFound errors
    Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessorJob: RecordNotFound error: #{e.message}"
    bulk_sync_event&.mark_as_failed!(e.message)
    raise e
  rescue => e
    # Handle any errors during processing
    error_message = e.message.presence || "Unknown error occurred"
    Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessorJob: Unexpected error processing bulk sync event #{bulk_sync_event_id}: #{error_message}"
    Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessorJob: Exception class: #{e.class.name}"
    Rails.logger.error "❌❌❌ AssignmentsBulkUploadProcessorJob: Backtrace: #{e.backtrace.first(20).join("\n")}" if e.backtrace
    bulk_sync_event&.mark_as_failed!(error_message)
    raise e
  end

  def self.perform_and_get_result(bulk_sync_event_id, organization_id)
    job = new
    job.perform(bulk_sync_event_id, organization_id)
  end
end
