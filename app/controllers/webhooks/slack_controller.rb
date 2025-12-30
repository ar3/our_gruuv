class Webhooks::SlackController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_slack_signature!
  
  def create
    # Parse the payload (Slack sends interactions as form-encoded with 'payload' param)
    payload_str = params[:payload].presence || request.raw_post
    payload = JSON.parse(payload_str)
    
    # Extract event type from payload
    event_type = payload['type'] || 'unknown'
    
    # Try to resolve organization from team.id if present
    organization = nil
    if payload['team'] && payload['team']['id']
      organization = Organization.find_by_slack_workspace_id(payload['team']['id'])
    end
    
    # Create incoming webhook record
    incoming_webhook = IncomingWebhook.create!(
      provider: 'slack',
      event_type: event_type,
      status: 'unprocessed',
      payload: payload,
      headers: whitelisted_headers,
      organization_id: organization&.id
    )
    
    # Handle message_action/shortcut immediately (trigger_id expires in 3 seconds)
    if event_type == 'message_action' || event_type == 'shortcut'
      handle_shortcut_immediately(incoming_webhook, payload, organization)
      head :ok
    elsif event_type == 'view_submission'
      # Handle view_submission synchronously (Slack requires response within 3 seconds)
      response = handle_view_submission_synchronously(incoming_webhook, payload, organization)
      render json: response
    else
      # For other events, process in background
      Slack::ProcessInteractionJob.perform_and_get_result(incoming_webhook.id)
      head :ok
    end
  rescue JSON::ParserError => e
    Rails.logger.error "Slack webhook: Failed to parse payload - #{e.message}"
    head :bad_request
  rescue => e
    Rails.logger.error "Slack webhook: Error processing request - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    head :internal_server_error
  end

  def event
    # Handle Slack Events API challenge/verification
    if params[:type] == 'url_verification'
      return render json: { challenge: params[:challenge] }
    end

    # Extract event type
    event_name = params.dig(:event, :type) || 'unknown-event'
    
    # Resolve organization from team_id
    team_id = params[:team_id]
    organization = Organization.find_by_slack_workspace_id(team_id) if team_id.present?
    
    # Only save if organization exists and has Slack configured
    if organization&.slack_configured?
      begin
        # Generate org_slug from organization name
        org_slug = organization.name.parameterize
        
        # Generate file path
        file_name = Time.zone.now.strftime('T%l:%M:%S%z').parameterize.underscore
        date_path = Time.zone.now.strftime('%Y/%m/%d/')
        path = "slack-events/#{Rails.env}/#{org_slug}/#{event_name}/#{date_path}"
        full_file_path_and_name = "#{path}#{file_name}.json"
        
        # Save to S3
        s3_client = S3::Client.new
        s3_client.save_json_to_s3(
          full_file_path_and_name: full_file_path_and_name,
          hash_object: params.to_unsafe_h
        )
      rescue => e
        Rails.logger.error "Slack Events API: Failed to save event to S3 - #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
      end
    end
    
    # Always return challenge response (even if saving failed or was skipped)
    render json: { challenge: params[:challenge] }
  rescue => e
    Rails.logger.error "Slack Events API: Error processing event - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    render json: { challenge: params[:challenge] }
  end
  
  private
  
  def verify_slack_signature!
    # Slack signature verification using HMAC-SHA256
    signing_secret = ENV['SLACK_SIGNING_SECRET']
    return head :unauthorized unless signing_secret.present?
    
    timestamp = request.headers['X-Slack-Request-Timestamp']
    signature = request.headers['X-Slack-Signature']
    
    return head :unauthorized unless timestamp.present? && signature.present?
    
    # Reject requests older than 5 minutes
    if Time.now.to_i - timestamp.to_i > 300
      return head :unauthorized
    end
    
    # Use raw_post to get the raw body before Rails parses form data
    # This is critical for form-encoded payloads like Slack interactions
    raw_body = request.raw_post
    
    # Create signature base string
    sig_basestring = "v0:#{timestamp}:#{raw_body}"
    
    # Compute signature
    computed_signature = 'v0=' + OpenSSL::HMAC.hexdigest(
      OpenSSL::Digest.new('sha256'),
      signing_secret,
      sig_basestring
    )
    
    # Debug logging in development
    if Rails.env.development?
      Rails.logger.debug "Slack signature verification:"
      Rails.logger.debug "  Raw body length: #{raw_body.length}"
      Rails.logger.debug "  Raw body preview: #{raw_body[0..100]}"
      Rails.logger.debug "  Timestamp: #{timestamp}"
      Rails.logger.debug "  Received signature: #{signature[0..20]}..."
      Rails.logger.debug "  Computed signature: #{computed_signature[0..20]}..."
    end
    
    # Compare signatures using secure comparison
    unless ActiveSupport::SecurityUtils.secure_compare(computed_signature, signature)
      Rails.logger.warn "Slack webhook: Signature verification failed"
      Rails.logger.warn "  Expected: #{computed_signature[0..20]}..."
      Rails.logger.warn "  Received: #{signature[0..20]}..."
      head :unauthorized
    end
  end
  
  def handle_view_submission_synchronously(incoming_webhook, payload, organization)
    callback_id = payload.dig('view', 'callback_id')
    
    case callback_id
    when 'goal_check_in'
      handle_goal_check_in_submission(incoming_webhook, payload, organization)
    when 'create_observation_from_message'
      # Observation modal is handled in background job (doesn't need immediate response)
      Slack::ProcessInteractionJob.perform_and_get_result(incoming_webhook.id)
      { response_action: 'clear' }
    else
      Rails.logger.warn "Slack webhook: Unknown callback_id: #{callback_id}"
      incoming_webhook.mark_failed!("Unknown callback_id: #{callback_id}")
      { response_action: 'clear' }
    end
  rescue => e
    Rails.logger.error "Slack webhook: Error handling view_submission - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    incoming_webhook.mark_failed!(e.message) if incoming_webhook
    { response_action: 'errors', errors: { base: 'An unexpected error occurred. Please try again.' } }
  end
  
  def handle_goal_check_in_submission(incoming_webhook, payload, organization)
    # Parse private metadata
    private_metadata_str = payload.dig('view', 'private_metadata')
    unless private_metadata_str
      incoming_webhook.mark_failed!("Missing private_metadata")
      return { response_action: 'errors', errors: { base: 'Missing metadata' } }
    end
    
    # Handle both string (from JSON) and hash (from JSONB) cases
    private_metadata = if private_metadata_str.is_a?(String)
      JSON.parse(private_metadata_str)
    else
      private_metadata_str.is_a?(Hash) ? private_metadata_str.with_indifferent_access : private_metadata_str
    end
    
    teammate_id = private_metadata['teammate_id'] || private_metadata[:teammate_id]
    organization_id = private_metadata['organization_id'] || private_metadata[:organization_id]
    
    # Resolve organization and teammate
    org = organization || Organization.find_by(id: organization_id)
    unless org
      incoming_webhook.mark_failed!("Organization not found")
      return { response_action: 'errors', errors: { base: 'Organization not found' } }
    end
    
    teammate = Teammate.find_by(id: teammate_id)
    unless teammate
      incoming_webhook.mark_failed!("Teammate not found for id: #{teammate_id}")
      return { response_action: 'errors', errors: { base: 'Teammate not found' } }
    end
    
    # Update webhook with organization if it was nil
    incoming_webhook.update!(organization_id: org.id) if incoming_webhook.organization_id.nil?
    
    # Extract form values
    state_values = payload.dig('view', 'state', 'values') || {}
    
    goal_selection_block = state_values['goal_selection'] || {}
    goal_id = goal_selection_block.dig('goal_selection', 'selected_option', 'value')
    
    confidence_percentage_block = state_values['confidence_percentage'] || {}
    confidence_percentage_str = confidence_percentage_block.dig('confidence_percentage', 'value')
    confidence_percentage = confidence_percentage_str.present? ? confidence_percentage_str.to_i : nil
    
    confidence_reason_block = state_values['confidence_reason'] || {}
    confidence_reason = confidence_reason_block.dig('confidence_reason', 'value')&.strip
    
    # Validate that we have a goal
    unless goal_id.present?
      return { response_action: 'errors', errors: { goal_selection: 'Please select a goal' } }
    end
    
    goal = Goal.find_by(id: goal_id)
    unless goal
      incoming_webhook.mark_failed!("Goal not found for id: #{goal_id}")
      return { response_action: 'errors', errors: { goal_selection: 'Selected goal not found' } }
    end
    
    # Validate that at least one field is present
    unless confidence_percentage.present? || confidence_reason.present?
      return { 
        response_action: 'errors', 
        errors: { 
          confidence_percentage: 'Either confidence percentage or reason must be provided',
          confidence_reason: 'Either confidence percentage or reason must be provided'
        } 
      }
    end
    
    # Validate confidence percentage range
    if confidence_percentage.present? && (confidence_percentage < 0 || confidence_percentage > 100)
      return { 
        response_action: 'errors', 
        errors: { confidence_percentage: 'Confidence percentage must be between 0 and 100' } 
      }
    end
    
    # Get current week start (Monday)
    week_start = Date.current.beginning_of_week(:monday)
    
    # Set PaperTrail whodunnit for version tracking
    PaperTrail.request.whodunnit = teammate.person.id.to_s
    
    # Find or initialize check-in for current week
    check_in = GoalCheckIn.find_or_initialize_by(
      goal: goal,
      check_in_week_start: week_start
    )
    
    check_in.assign_attributes(
      confidence_percentage: confidence_percentage,
      confidence_reason: confidence_reason,
      confidence_reporter: teammate.person
    )
    
    if check_in.save
      # Auto-complete goal if confidence is 0% or 100%
      if (confidence_percentage == 0 || confidence_percentage == 100) && goal.completed_at.nil?
        goal.update(completed_at: Time.current)
      end
      
      # Link the webhook to the created check-in
      incoming_webhook.update!(resultable: check_in)
      incoming_webhook.mark_processed!
      
      # Post confirmation message asynchronously
      user_id = private_metadata['user_id'] || private_metadata[:user_id]
      if user_id.present?
        Slack::PostGoalCheckInConfirmationJob.perform_later(org.id, user_id, goal.id)
      end
      
      # Return success response to close the modal
      { response_action: 'clear' }
    else
      error_message = "Failed to save check-in: #{check_in.errors.full_messages.join(', ')}"
      Rails.logger.error "Slack webhook: #{error_message}"
      incoming_webhook.mark_failed!(error_message)
      
      # Return errors to show in modal
      errors_hash = {}
      check_in.errors.each do |error|
        field = error.attribute.to_s
        errors_hash[field] = error.message
      end
      
      { response_action: 'errors', errors: errors_hash }
    end
  end

  def handle_shortcut_immediately(incoming_webhook, payload, organization)
    unless organization
      incoming_webhook.mark_failed!("Organization not found for workspace")
      Rails.logger.error "Slack webhook: Organization not found for team_id: #{payload.dig('team', 'id')}"
      return
    end
    
    unless organization.slack_configured?
      incoming_webhook.mark_failed!("Slack not configured for organization")
      Rails.logger.error "Slack webhook: Slack not configured for organization #{organization.id}"
      return
    end
    
    # Extract trigger_id and message info
    trigger_id = payload['trigger_id']
    unless trigger_id.present?
      incoming_webhook.mark_failed!("Missing trigger_id in payload")
      Rails.logger.error "Slack webhook: Missing trigger_id in payload"
      return
    end
    
    team_id = payload.dig('team', 'id')
    channel_id = payload.dig('channel', 'id')
    message_ts = payload.dig('message', 'ts')
    message_user_id = payload.dig('message', 'user') || payload.dig('message', 'user_id')
    triggering_user_id = payload['user']&.dig('id') || payload['user_id']
    
    # Build private metadata for modal
    private_metadata = {
      team_id: team_id,
      channel_id: channel_id,
      message_ts: message_ts,
      message_user_id: message_user_id,
      triggering_user_id: triggering_user_id
    }.to_json
    
    # Open the modal immediately (trigger_id expires in 3 seconds)
    begin
      slack_service = SlackService.new(organization)
      result = slack_service.open_create_observation_modal(trigger_id, private_metadata)
      
      if result[:success]
        incoming_webhook.mark_processed!
        Rails.logger.info "Slack webhook: Modal opened successfully for trigger_id: #{trigger_id}"
      else
        error_msg = result[:error] || "Failed to open modal"
        incoming_webhook.mark_failed!(error_msg)
        Rails.logger.error "Slack webhook: Failed to open modal - #{error_msg}"
      end
    rescue => e
      Rails.logger.error "Slack webhook: Error opening modal - #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      incoming_webhook.mark_failed!(e.message)
    end
  end
  
  def whitelisted_headers
    {
      'X-Slack-Request-Timestamp' => request.headers['X-Slack-Request-Timestamp'],
      'X-Slack-Signature' => request.headers['X-Slack-Signature'],
      'Content-Type' => request.headers['Content-Type'],
      'User-Agent' => request.headers['User-Agent']
    }
  end
end


