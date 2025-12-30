class Webhooks::SlackCommandsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_slack_signature!
  
  def create
    # Slack slash commands come as form-encoded POST requests
    # Extract command parameters
    command = params[:command] # e.g., "/og"
    text = params[:text].to_s # e.g., "feedback Great work @user1!"
    user_id = params[:user_id]
    team_id = params[:team_id]
    channel_id = params[:channel_id]
    response_url = params[:response_url]
    trigger_id = params[:trigger_id]
    
    # Debug logging in development
    if Rails.env.development?
      Rails.logger.debug "Slack command received:"
      Rails.logger.debug "  command: #{command.inspect}"
      Rails.logger.debug "  text: #{text.inspect}"
      Rails.logger.debug "  user_id: #{user_id}"
      Rails.logger.debug "  team_id: #{team_id}"
    end
    
    # Resolve organization from team_id
    organization = Organization.find_by_slack_workspace_id(team_id)
    
    # Create incoming webhook record for tracking
    incoming_webhook = IncomingWebhook.create!(
      provider: 'slack',
      event_type: 'slash_command',
      status: 'unprocessed',
      payload: params.to_unsafe_h,
      headers: whitelisted_headers,
      organization_id: organization&.id
    )
    
    # Parse action from text parameter
    action, remaining_text = parse_action(text)
    
    # Handle help or empty command
    if action.nil? || action == 'help'
      incoming_webhook.mark_processed!
      return render json: { text: build_help_message }
    end
    
    # Route to appropriate handler
    result = case action
    when 'feedback'
      handle_feedback_command(organization, user_id, channel_id, remaining_text, incoming_webhook)
    when 'huddle'
      handle_huddle_command(organization, user_id, channel_id, incoming_webhook)
    when 'goal-check'
      handle_goal_check_command(organization, user_id, trigger_id, incoming_webhook)
    else
      { text: "Unknown command. #{build_help_message}" }
    end
    
    # Convert Result objects to hash format for Slack
    if result.is_a?(Result)
      if result.ok?
        incoming_webhook.mark_processed!
        result = { text: result.value }
      else
        incoming_webhook.mark_failed!(result.error)
        result = { text: result.error }
      end
    elsif result.is_a?(Hash) && result[:success] != false
      incoming_webhook.mark_processed!
    elsif result.is_a?(Hash) && result[:success] == false
      incoming_webhook.mark_failed!(result[:error])
    else
      incoming_webhook.mark_processed!
    end
    
    # Return response (Slack expects JSON with text field for slash commands)
    render json: result
  rescue => e
    Rails.logger.error "Slack command: Error processing request - #{e.message}"
    Rails.logger.error e.backtrace.first(10).join("\n")
    
    if incoming_webhook
      incoming_webhook.mark_failed!(e.message)
    end
    
    render json: { text: "An error occurred processing your command. Please try again." }
  end
  
  private
  
  def parse_action(text)
    return [nil, nil] if text.blank?
    
    parts = text.split(' ', 2)
    action = parts[0]&.downcase
    remaining_text = parts[1]
    
    # Normalize aliases
    action = case action
    when 'observe', 'kudos', 'note'
      'feedback'
    when 'goalcheck', 'checkin', 'check-in'
      'goal-check'
    else
      action
    end
    
    [action, remaining_text]
  end

  def build_help_message
    <<~HELP
      *OurGruuv Slack Commands*

      Available commands:
      • `/og feedback <message>` - Create an observation. You can mention people with @username to add them as observees. Aliases: `observe`, `kudos`, `note`
      • `/og huddle` - Start a huddle for the current channel (if configured)
      • `/og goal-check` - Check in on your goals for the current week

      Use `/og help` to see this message again.
    HELP
  end
  
  def handle_goal_check_command(organization, user_id, trigger_id, incoming_webhook)
    unless organization
      return Result.err("Organization not found for this Slack workspace. Please ensure Slack is properly configured.")
    end
    
    unless organization.slack_configured?
      return Result.err("Slack is not configured for this organization. Please configure Slack integration first.")
    end
    
    unless trigger_id.present?
      return Result.err("Missing trigger_id. Please try the command again.")
    end
    
    # Extract command information for trigger (if we want to track this later)
    command_info = {
      command: params[:command],
      user_id: user_id,
      team_id: params[:team_id],
      team_domain: params[:team_domain],
      channel_id: params[:channel_id],
      channel_name: params[:channel_name],
      user_name: params[:user_name],
      response_url: params[:response_url],
      trigger_id: trigger_id
    }
    
    Slack::ProcessGoalCheckCommandService.call(
      organization: organization,
      user_id: user_id,
      trigger_id: trigger_id,
      command_info: command_info
    )
  end

  def handle_huddle_command(organization, user_id, channel_id, incoming_webhook)
    unless organization
      return Result.err("Organization not found for this Slack workspace. Please ensure Slack is properly configured.")
    end
    
    unless organization.slack_configured?
      return Result.err("Slack is not configured for this organization. Please configure Slack integration first.")
    end
    
    # Extract command information for trigger (if we want to track this later)
    command_info = {
      command: params[:command],
      user_id: user_id,
      channel_id: channel_id,
      team_id: params[:team_id],
      team_domain: params[:team_domain],
      channel_name: params[:channel_name],
      user_name: params[:user_name],
      response_url: params[:response_url],
      trigger_id: params[:trigger_id]
    }
    
    Slack::ProcessHuddleCommandService.call(
      organization: organization,
      user_id: user_id,
      channel_id: channel_id,
      command_info: command_info
    )
  end

  def handle_feedback_command(organization, user_id, channel_id, text, incoming_webhook)
    unless organization
      return { text: "Organization not found for this Slack workspace. Please ensure Slack is properly configured." }
    end
    
    unless organization.slack_configured?
      return { text: "Slack is not configured for this organization. Please configure Slack integration first." }
    end
    
    # Extract command information for trigger
    command_info = {
      command: params[:command],
      text: text,
      user_id: user_id,
      channel_id: channel_id,
      team_id: params[:team_id],
      team_domain: params[:team_domain],
      channel_name: params[:channel_name],
      user_name: params[:user_name],
      response_url: params[:response_url],
      trigger_id: params[:trigger_id]
    }
    
    # Process the feedback command
    result = Slack::ProcessFeedbackCommandService.call(
      organization: organization,
      user_id: user_id,
      channel_id: channel_id,
      text: text,
      command_info: command_info
    )
    
    if result.ok?
      observation = result.value
      observation_url = Rails.application.routes.url_helpers.organization_observation_url(
        organization,
        observation,
        host: Rails.application.config.action_mailer.default_url_options[:host] || 'localhost:3000'
      )
      {
        text: "Observation created successfully! View it here: #{observation_url}",
        response_type: 'ephemeral' # Only visible to the user who ran the command
      }
    else
      {
        text: "Failed to create observation: #{result.error}",
        response_type: 'ephemeral'
      }
    end
  end
  
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
    # This is critical for form-encoded payloads like Slack slash commands
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
      Rails.logger.warn "Slack command: Signature verification failed"
      Rails.logger.warn "  Expected: #{computed_signature[0..20]}..."
      Rails.logger.warn "  Received: #{signature[0..20]}..."
      head :unauthorized
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

