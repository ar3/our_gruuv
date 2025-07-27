class Huddles::PostAnnouncementJob < ApplicationJob
  queue_as :default

  def perform(huddle_id)
    huddle = Huddle.find(huddle_id)
    
    # Check if Slack is configured for this organization
    unless huddle.slack_configured?
      Rails.logger.info "Slack not configured for organization #{huddle.organization.id}, skipping announcement"
      return
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
      
      # Update the existing message
      SlackService.new(huddle.organization).update_message(notification.id)
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
      
      # Post new message
      SlackService.new(huddle.organization).post_message(notification.id)
    end
  end

  private

  def build_announcement_fallback_text(huddle)
    "🚀 #{huddle.display_name} - Starting Now! The huddle is starting! Join in to participate in today's collaborative session. 👥 #{huddle.huddle_participants.count} participants • Facilitated by #{huddle.facilitator_names.join(', ')}"
  end

  def build_announcement_blocks(huddle)
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
            text: "👥 #{huddle.huddle_participants.count} participants • Facilitated by #{huddle.facilitator_names.join(', ')}"
          }
        ]
      }
    ]
  end
end 