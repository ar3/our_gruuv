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
    join_url = generate_join_url(huddle)
    case determine_announcement_state(huddle)
    when :single_participant
      "🚀 #{huddle.display_name} - Starting Now! The huddle is starting! Join in to participate in today's collaborative session. 👥 #{huddle.huddle_participants.count} participants • Facilitated by #{huddle.facilitator_names.join(', ')} • Join: #{join_url}"
    when :completed_conquest
      "🏆 #{huddle.display_name} - We came, we huddled, we conquered! 🎉 All #{huddle.huddle_participants.count} participants have given feedback. Great work team! • View: #{join_url}"
    when :waiting_for_feedback
      "⏳ #{huddle.display_name} - We have #{huddle.huddle_feedbacks.count} participant(s) who have given feedback and we are waiting on #{huddle.huddle_participants.count - huddle.huddle_feedbacks.count} others. • Join: #{join_url}"
    end
  end

  def build_announcement_blocks(huddle)
    join_url = generate_join_url(huddle)
    case determine_announcement_state(huddle)
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
              text: "👥 #{huddle.huddle_participants.count} participants • Facilitated by #{huddle.facilitator_names.join(', ')}"
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
                text: "Join Huddle",
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
            text: "We have #{huddle.huddle_feedbacks.count} participant(s) who have given feedback and we are waiting on #{huddle.huddle_participants.count - huddle.huddle_feedbacks.count} others."
          }
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "📊 #{huddle.huddle_feedbacks.count}/#{huddle.huddle_participants.count} participants submitted feedback • #{((huddle.huddle_feedbacks.count.to_f / huddle.huddle_participants.count) * 100).round}% complete"
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
    
    if participant_count == 1
      :single_participant
    elsif participant_count >= 3 && feedback_count == participant_count
      :completed_conquest
    else
      :waiting_for_feedback
    end
  end

  def generate_join_url(huddle)
    # Try to get the host from Rails configuration
    host = Rails.application.config.action_mailer.default_url_options&.dig(:host) ||
           ENV['RAILS_HOST'] ||
           'localhost:3000'
    
    # Generate the URL with the host
    Rails.application.routes.url_helpers.join_huddle_url(huddle, host: host)
  rescue => e
    # Fallback to just the path if URL generation fails
    Rails.logger.warn "Failed to generate full URL for huddle #{huddle.id}: #{e.message}"
    Rails.application.routes.url_helpers.join_huddle_path(huddle)
  end
end 