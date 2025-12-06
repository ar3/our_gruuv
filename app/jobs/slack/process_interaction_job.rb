class Slack::ProcessInteractionJob < ApplicationJob
  queue_as :default
  
  def perform(incoming_webhook_id)
    incoming_webhook = IncomingWebhook.find_by(id: incoming_webhook_id)
    return unless incoming_webhook
    
    # Mark as processing (with optimistic locking to avoid double-processing)
    return unless incoming_webhook.status == 'unprocessed'
    incoming_webhook.mark_processing!
    
    payload = incoming_webhook.payload
    event_type = payload['type']
    
    case event_type
    when 'view_submission'
      handle_view_submission(incoming_webhook, payload)
    when 'message_action', 'shortcut'
      # These are handled immediately in the controller (trigger_id expires too quickly)
      # This should not normally be reached, but handle gracefully if it is
      Rails.logger.warn "Slack::ProcessInteractionJob: Received #{event_type} in background job (should be handled in controller)"
      incoming_webhook.mark_failed!("Event type #{event_type} should be handled synchronously")
    else
      Rails.logger.warn "Slack::ProcessInteractionJob: Unknown event type: #{event_type}"
      incoming_webhook.mark_failed!("Unknown event type: #{event_type}")
    end
  rescue => e
    Rails.logger.error "Slack::ProcessInteractionJob: Error processing webhook #{incoming_webhook_id} - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    
    if incoming_webhook
      incoming_webhook.mark_failed!(e.message)
    end
  end
  
  private
  
  def handle_view_submission(incoming_webhook, payload)
    # Check if this is our observation creation modal
    callback_id = payload.dig('view', 'callback_id')
    return unless callback_id == 'create_observation_from_message'
    
    # Parse private metadata
    private_metadata_str = payload.dig('view', 'private_metadata')
    return unless private_metadata_str
    
    private_metadata = JSON.parse(private_metadata_str)
    team_id = private_metadata['team_id']
    channel_id = private_metadata['channel_id']
    message_ts = private_metadata['message_ts']
    message_user_id = private_metadata['message_user_id']
    triggering_user_id = private_metadata['triggering_user_id']
    
    # Resolve organization
    organization = Organization.find_by_slack_workspace_id(team_id)
    unless organization
      incoming_webhook.mark_failed!("Organization not found for workspace_id: #{team_id}")
      return
    end
    
    # Update webhook with organization if it was nil
    incoming_webhook.update!(organization_id: organization.id) if incoming_webhook.organization_id.nil?
    
    # Extract form values
    state_values = payload.dig('view', 'state', 'values') || {}
    share_in_thread_block = state_values['share_in_thread'] || {}
    share_in_thread_value = share_in_thread_block.dig('share_in_thread', 'selected_option', 'value') || 'yes'
    notes_block = state_values['notes'] || {}
    notes = notes_block.dig('notes', 'value') || ''
    
    # Create observation using Slack::CreateObservationFromMessageService
    service = Slack::CreateObservationFromMessageService.new(
      organization: organization,
      team_id: team_id,
      channel_id: channel_id,
      message_ts: message_ts,
      message_user_id: message_user_id,
      triggering_user_id: triggering_user_id,
      notes: notes
    )
    
    result = service.call
    
    if result.ok?
      observation = result.value
      
      # Link the webhook to the created observation
      incoming_webhook.update!(resultable: observation)
      
      # Build observation URL
      url_options = Rails.application.routes.default_url_options || {}
      observation_url = Rails.application.routes.url_helpers.organization_observation_url(
        organization,
        observation,
        url_options
      )
      
      # Post message to thread or DM based on user preference
      slack_service = SlackService.new(organization)
      
      if share_in_thread_value == 'yes'
        thread_result = slack_service.post_message_to_thread(
          channel_id: channel_id,
          thread_ts: message_ts,
          text: "📝 Draft observation created: #{observation_url}"
        )
        
        unless thread_result[:success]
          Rails.logger.error "Slack::ProcessInteractionJob: Failed to post thread message - #{thread_result[:error]}"
        end
      else
        dm_result = slack_service.post_dm(
          user_id: triggering_user_id,
          text: "📝 Draft observation created: #{observation_url}"
        )
        
        unless dm_result[:success]
          Rails.logger.error "Slack::ProcessInteractionJob: Failed to post DM - #{dm_result[:error]}"
        end
      end
      
      incoming_webhook.mark_processed!
    else
      error_message = result.error
      Rails.logger.error "Slack::ProcessInteractionJob: Failed to create observation - #{error_message}"
      incoming_webhook.mark_failed!(error_message)
    end
  end
end


