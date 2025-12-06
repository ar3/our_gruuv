class Slack::CreateObservationFromMessageService
  def initialize(organization:, team_id:, channel_id:, message_ts:, message_user_id:, triggering_user_id:, notes:)
    @organization = organization
    @team_id = team_id
    @channel_id = channel_id
    @message_ts = message_ts
    @message_user_id = message_user_id
    @triggering_user_id = triggering_user_id
    @notes = notes
    @slack_service = SlackService.new(@organization)
  end

  def call
    # 1. Resolve observer (the person who triggered the shortcut)
    observer_teammate = TeammateIdentity.find_teammate_by_slack_id(@triggering_user_id, @organization)
    unless observer_teammate
      log_debug_response("create_observation_from_message", { status: 'failed', reason: 'Observer not found' }, { error: "Observer (triggering user) not found in OurGruuv." })
      return Result.err("Observer (triggering user) not found in OurGruuv.")
    end

    # 2. Resolve observee (the person who authored the Slack message)
    observee_teammate = TeammateIdentity.find_teammate_by_slack_id(@message_user_id, @organization)
    # Per user preference, if observee is not found, skip adding them, but still create observation.

    # 3. Get Slack message permalink
    permalink_result = @slack_service.get_message_permalink(@channel_id, @message_ts)
    unless permalink_result[:success]
      log_debug_response("create_observation_from_message", { status: 'failed', reason: 'Permalink not found' }, { error: permalink_result[:error] })
      return Result.err("Failed to get Slack message permalink: #{permalink_result[:error]}")
    end
    slack_message_permalink = permalink_result[:permalink]

    # 4. Build observation story
    story_content = @notes.present? ? "#{@notes}\n\n" : ""
    story_content += "Original Slack message: #{slack_message_permalink}"

    # 5. Create draft observation
    observation = @organization.observations.build(
      observer: observer_teammate.person,
      story: story_content,
      privacy_level: :observed_and_managers, # Default to a safe internal level
      observed_at: Time.current,
      published_at: nil # Ensure it's a draft
    )

    if observee_teammate
      observation.observees.build(teammate: observee_teammate)
    end

    if observation.save
      log_debug_response("create_observation_from_message", { status: 'success', observation_id: observation.id }, { observation_url: Rails.application.routes.url_helpers.organization_observation_url(@organization, observation) })
      Result.ok(observation)
    else
      error_message = "Failed to create observation: #{observation.errors.full_messages.join(', ')}"
      log_debug_response("create_observation_from_message", { status: 'failed', errors: observation.errors.full_messages }, { error: error_message })
      Result.err(error_message)
    end
  rescue => e
    error_message = "Unexpected error creating observation: #{e.message}"
    log_debug_response("create_observation_from_message", { status: 'failed', exception: e.class.name }, { error: error_message, backtrace: e.backtrace.first(5) })
    Result.err(error_message)
  end

  private

  def log_debug_response(method, request_params, response_data)
    @slack_service.store_slack_response(method, request_params, response_data)
  end
end

