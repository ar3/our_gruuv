class Huddles::PostAnnouncementJob < ApplicationJob
  queue_as :default

  def perform(huddle_id)
    huddle = Huddle.find(huddle_id)
    
    # Check if Slack is configured for this organization
    unless huddle.slack_configured?
      result = { success: false, error: "Slack not configured for organization #{huddle.organization&.id}" }
      Rails.logger.info "Slack not configured for organization #{huddle.organization&.id}, skipping announcement"
      return result
    end
    
    # Check if announcement already exists
    existing_announcement = huddle.notifications.announcements.successful.first
    
    if existing_announcement
      # Create new notification for update
      blocks = build_announcement_blocks(huddle)
      notification = huddle.notifications.create!(
        notification_type: 'huddle_announcement',
        original_message: existing_announcement,
        status: 'preparing_to_send',
        metadata: { channel: huddle.slack_channel },
        rich_message: blocks,
        fallback_text: build_announcement_fallback_text(huddle)
      )
      
      Rails.logger.info "Updating existing announcement for huddle #{huddle.id}"
      
      # Update the existing message
      result = SlackService.new(huddle.organization).update_message(notification.id)
      
      if result[:success]
        { success: true, action: 'updated', huddle_id: huddle.id, notification_id: notification.id, message_id: result[:message_id] }
      else
        { success: false, action: 'update_failed', huddle_id: huddle.id, notification_id: notification.id, error: result[:error] }
      end
    else
      # Create new notification
      blocks = build_announcement_blocks(huddle)
      notification = huddle.notifications.create!(
        notification_type: 'huddle_announcement',
        status: 'preparing_to_send',
        metadata: { channel: huddle.slack_channel },
        rich_message: blocks,
        fallback_text: build_announcement_fallback_text(huddle)
      )
      
      Rails.logger.info "Creating new announcement for huddle #{huddle.id}"
      
      # Post new message
      result = SlackService.new(huddle.organization).post_message(notification.id)
      
      if result[:success]
        { success: true, action: 'posted', huddle_id: huddle.id, notification_id: notification.id, message_id: result[:message_id] }
      else
        { success: false, action: 'post_failed', huddle_id: huddle.id, notification_id: notification.id, error: result[:error] }
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    error_msg = "Huddle with ID #{huddle_id} not found"
    Rails.logger.error error_msg
    { success: false, error: error_msg }
  rescue => e
    error_msg = "Unexpected error in PostAnnouncementJob: #{e.message}"
    Rails.logger.error error_msg
    Rails.logger.error e.backtrace.first(5).join("\n")
    { success: false, error: error_msg }
  end

  private

  def build_announcement_fallback_text(huddle)
    join_url = generate_join_url(huddle)
    case determine_announcement_state(huddle)
    when :no_participants
      "🚀 #{huddle.display_name} - A new huddle is starting! Be the first to join and give feedback about today's collaborative session. • Join: #{join_url}"
    when :single_participant
      "🚀 #{huddle.display_name} - Participate / give feedback about today's collaborative session. 👥 #{huddle.huddle_participants.count} participants#{huddle.facilitator_names.any? ? " • Facilitated by #{huddle.facilitator_names.join(', ')}" : ""} • Join: #{join_url}"
    when :completed_conquest
      "🏆 #{huddle.display_name} - We came, we huddled, we conquered! 🎉 All #{huddle.huddle_participants.count} participants have given feedback. Great work team! • View: #{join_url}"
    when :waiting_for_feedback
      "⏳ #{huddle.display_name} - We have #{huddle.huddle_feedbacks.count} participant(s) who have given feedback#{huddle.huddle_participants.count > 0 ? " and we are waiting on #{huddle.huddle_participants.count - huddle.huddle_feedbacks.count} others" : ""}. • Join: #{join_url}"
    end
  end

  def build_announcement_blocks(huddle)
    join_url = generate_join_url(huddle)
    case determine_announcement_state(huddle)
    when :no_participants
      [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "🚀 #{huddle.display_name} - New Huddle Starting!",
            emoji: true
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "A new huddle is starting! Be the first to join and give feedback about today's collaborative session."
          }
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "👥 0 participants • Ready for you to join!"
            }
          ]
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: "Join & Give Feedback",
                emoji: true
              },
              style: "primary",
              url: join_url
            }
          ]
        }
      ]
    when :single_participant
      [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "🚀 #{huddle.display_name} - Starting Now!",
            emoji: true
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "The huddle is starting! Join in to participate in today's collaborative session."
          }
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "👥 #{huddle.huddle_participants.count} participants#{huddle.facilitator_names.any? ? " • Facilitated by #{huddle.facilitator_names.join(', ')}" : ""}"
            }
          ]
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: "Join & Give Feedback",
                emoji: true
              },
              style: "primary",
              url: join_url
            }
          ]
        }
      ]
    when :completed_conquest
      [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "🏆 #{huddle.display_name} - We came, we huddled, we conquered!",
            emoji: true
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "🎉 All #{huddle.huddle_participants.count} participants have given feedback. Great work team!"
          }
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "✅ 100% participation achieved • Nat 20 Score: #{huddle.nat_20_score || 'N/A'}"
            }
          ]
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: "View Huddle",
                emoji: true
              },
              style: "primary",
              url: join_url
            }
          ]
        }
      ]
    when :waiting_for_feedback
      [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "⏳ #{huddle.display_name} - Waiting for Feedback",
            emoji: true
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "We have #{huddle.huddle_feedbacks.count} participant(s) who have given feedback#{huddle.huddle_participants.count > 0 ? " and we are waiting on #{huddle.huddle_participants.count - huddle.huddle_feedbacks.count} others" : ""}."
          }
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "📊 #{huddle.huddle_feedbacks.count}/#{huddle.huddle_participants.count} participants submitted feedback#{huddle.huddle_participants.count > 0 ? " • #{((huddle.huddle_feedbacks.count.to_f / huddle.huddle_participants.count) * 100).round}% complete" : ""}"
            }
          ]
        },
        {
          type: "actions",
          elements: [
            {
              type: "button",
              text: {
                type: "plain_text",
                text: "Join & Give Feedback",
                emoji: true
              },
              style: "primary",
              url: join_url
            }
          ]
        }
      ]
    end
  end

  def determine_announcement_state(huddle)
    participant_count = huddle.huddle_participants.count
    feedback_count = huddle.huddle_feedbacks.count
    
    if participant_count == 0
      :no_participants
    elsif participant_count == 1
      :single_participant
    elsif participant_count >= 3 && feedback_count == participant_count
      :completed_conquest
    else
      :waiting_for_feedback
    end
  end

  def generate_join_url(huddle)
    # Use Rails' built-in URL generation with configured default options
    Rails.application.routes.url_helpers.join_huddle_url(huddle)
  rescue => e
    # Fallback to just the path if URL generation fails
    Rails.logger.warn "Failed to generate full URL for huddle #{huddle.id}: #{e.message}"
    Rails.application.routes.url_helpers.join_huddle_path(huddle)
  end
end 