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
    else
      # For other events (like view_submission), process in background
      Slack::ProcessInteractionJob.perform_and_get_result(incoming_webhook.id)
    end
    
    # Return 200 immediately (Slack expects quick response)
    head :ok
  rescue JSON::ParserError => e
    Rails.logger.error "Slack webhook: Failed to parse payload - #{e.message}"
    head :bad_request
  rescue => e
    Rails.logger.error "Slack webhook: Error processing request - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    head :internal_server_error
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


