class Huddles::PostFeedbackJob < ApplicationJob
  queue_as :default

  def perform(huddle_id, feedback_id)
    huddle = Huddle.find(huddle_id)
    feedback = HuddleFeedback.find(feedback_id)
    
    # Check if Slack is configured for this organization
    unless huddle.slack_configured?
      Rails.logger.info "Slack not configured for organization #{huddle.organization.id}, skipping feedback"
      return
    end
    
    # Ensure announcement exists first (this will also create summary if needed)
    announcement_notification = huddle.slack_announcement_notification
    
    if announcement_notification.nil?
      # Create announcement and summary first
      Huddles::PostAnnouncementJob.perform_now(huddle_id)
      Huddles::PostSummaryJob.perform_now(huddle_id)
      announcement_notification = huddle.reload.slack_announcement_notification
    end
    
    # Create new feedback notification
    blocks = build_feedback_blocks(feedback)
    feedback_notification = huddle.notifications.create!(
      notification_type: 'huddle_feedback',
      main_thread: announcement_notification,
      status: 'preparing_to_send',
      metadata: { channel: huddle.slack_channel },
      rich_message: blocks,
      fallback_text: build_feedback_fallback_text(feedback)
    )
    
    # Post new message in thread
    SlackService.new(huddle.organization).post_message(feedback_notification.id)
  end

  private

  def build_feedback_fallback_text(feedback)
    "💬 New Feedback from #{feedback.display_name} • Rating: #{feedback.nat_20_score}/20"
  end

  def build_feedback_blocks(feedback)
    [
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*💬 New Feedback from #{feedback.display_name}*"
        }
      },
      {
        type: "section",
        fields: [
          {
            type: "mrkdwn",
            text: "*Rating:*\n#{feedback.nat_20_score}/20"
          }
        ]
      }
    ]
  end
end 