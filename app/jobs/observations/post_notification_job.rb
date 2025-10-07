class Observations::PostNotificationJob < ApplicationJob
  queue_as :default

  def perform(observation_id, notification_options = {})
    @observation = Observation.find(observation_id)
    @notification_options = notification_options.with_defaults(
      send_dms: true,
      send_to_channels: false,
      channel_ids: []
    )

    return unless @observation.can_post_to_slack?

    send_dm_notifications if @notification_options[:send_dms]
    send_channel_notifications if @notification_options[:send_to_channels]
  end

  private

  def send_dm_notifications
    @observation.observed_teammates.each do |teammate|
      slack_identity = teammate.person.person_identities.find_by(provider: 'slack')
      next unless slack_identity&.uid.present?

      message = build_dm_message(teammate)
      
      notification = @observation.notifications.create!(
        notification_type: 'observation_dm',
        message_id: nil, # Will be set after Slack API call
        rich_message: message,
        fallback_text: strip_markdown(message),
        status: 'preparing_to_send',
        metadata: {
          teammate_id: teammate.id,
          person_id: teammate.person.id,
          slack_user_id: slack_identity.uid,
          channel: slack_identity.uid # For DMs, channel is the user ID
        }
      )

      begin
        # Use SlackService to post the message
        slack_service = SlackService.new(@observation.company)
        response = slack_service.post_message(notification.id)
        
        if response[:success]
          # Update notification with success
          notification.update!(
            status: 'sent_successfully',
            message_id: response[:message_id],
            metadata: notification.metadata.merge(response)
          )
        else
          # Update notification with failure
          notification.update!(
            status: 'send_failed',
            metadata: notification.metadata.merge({ error: response[:error] })
          )
        end
      rescue => e
        # Update notification with failure
        notification.update!(
          status: 'send_failed',
          metadata: notification.metadata.merge({ error: e.message, backtrace: e.backtrace.first(5) })
        )
        Rails.logger.error "Failed to send DM to #{teammate.person.email}: #{e.message}"
      end
    end
  end

  def send_channel_notifications
    @notification_options[:channel_ids].each do |channel_id|
      message = build_channel_message
      
      notification = @observation.notifications.create!(
        notification_type: 'observation_channel',
        message_id: nil, # Will be set after Slack API call
        rich_message: message,
        fallback_text: strip_markdown(message),
        status: 'preparing_to_send',
        metadata: {
          channel_id: channel_id,
          observation_id: @observation.id,
          channel: channel_id # SlackService expects 'channel' key
        }
      )

      begin
        # Use SlackService to post the message
        slack_service = SlackService.new(@observation.company)
        response = slack_service.post_message(notification.id)
        
        if response[:success]
          # Update notification with success
          notification.update!(
            status: 'sent_successfully',
            message_id: response[:message_id],
            metadata: notification.metadata.merge(response)
          )
        else
          # Update notification with failure
          notification.update!(
            status: 'send_failed',
            metadata: notification.metadata.merge({ error: response[:error] })
          )
        end
      rescue => e
        # Update notification with failure
        notification.update!(
          status: 'send_failed',
          metadata: notification.metadata.merge({ error: e.message, backtrace: e.backtrace.first(5) })
        )
        Rails.logger.error "Failed to post to channel #{channel_id}: #{e.message}"
      end
    end
  end

  def build_dm_message(teammate)
    feelings_text = @observation.decorate.feelings_display_html
    ratings_summary = build_ratings_summary(positive_only: true)
    
    <<~MESSAGE
      🎯 New Observation from #{@observation.observer.preferred_name || @observation.observer.first_name}
      
      #{feelings_text}
      
      #{@observation.story.truncate(200)}
      
      Privacy: #{@observation.decorate.visibility_text}
      #{ratings_summary}
      
      [View Kudos] → #{kudos_url(@observation.permalink_id)}
    MESSAGE
  end

  def build_channel_message
    feelings_text = @observation.decorate.feelings_display_html
    observees_text = @observation.observed_teammates.map(&:person).map { |p| p.preferred_name || p.first_name }.join(', ')
    ratings_summary = build_ratings_summary(positive_only: true)
    
    <<~MESSAGE
      🎯 #{@observation.observer.preferred_name || @observation.observer.first_name} recognized #{observees_text}
      
      #{feelings_text}
      
      #{@observation.story}
      
      #{ratings_summary}
      
      [View Kudos] → #{kudos_url(@observation.permalink_id)}
    MESSAGE
  end

  def build_ratings_summary(positive_only: false)
    ratings = @observation.observation_ratings.includes(:rateable)
    ratings = ratings.positive if positive_only
    
    return '' if ratings.empty?
    
    rating_texts = ratings.map do |rating|
      "#{rating.decorate.rating_icon} #{rating.rateable.name}"
    end
    
    "Ratings: #{rating_texts.join(', ')}"
  end

  def strip_markdown(text)
    text.gsub(/\*\*(.*?)\*\*/, '\1')
        .gsub(/\*(.*?)\*/, '\1')
        .gsub(/\[([^\]]+)\]\([^)]+\)/, '\1')
  end

  def kudos_url(permalink_id)
    # Parse the permalink_id to extract date and id
    # Format: "2025-10-05-142" or "2025-10-05-142-custom-slug"
    parts = permalink_id.split('-')
    date_part = "#{parts[0]}-#{parts[1]}-#{parts[2]}"
    id_part = parts[3]
    
    Rails.application.routes.url_helpers.kudos_url(date: date_part, id: id_part)
  end
end
