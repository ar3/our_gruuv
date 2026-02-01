class Huddles::PostFeedbackJob < ApplicationJob
  queue_as :default

  def perform(huddle_id, feedback_id)
    huddle = Huddle.find(huddle_id)
    feedback = HuddleFeedback.find(feedback_id)
    
    # Check if Slack huddle channel is configured for this team
    unless huddle.slack_configured?
      result = { success: false, error: "Slack huddle channel not configured for team #{huddle.team&.id}" }
      Rails.logger.info "Slack huddle channel not configured for team #{huddle.team&.id}, skipping feedback"
      return result
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
    
    Rails.logger.info "Posting feedback for huddle #{huddle.id}, feedback #{feedback_id}"
    
    # Post new message in thread
    result = SlackService.new(huddle.company).post_message(feedback_notification.id)
    
    if result[:success]
      { success: true, action: 'posted_feedback', huddle_id: huddle.id, feedback_id: feedback_id, notification_id: feedback_notification.id, message_id: result[:message_id] }
    else
      { success: false, action: 'post_feedback_failed', huddle_id: huddle.id, feedback_id: feedback_id, notification_id: feedback_notification.id, error: result[:error] }
    end
  rescue ActiveRecord::RecordNotFound => e
    error_msg = "Record not found: #{e.message}"
    Rails.logger.error error_msg
    { success: false, error: error_msg }
  rescue => e
    error_msg = "Unexpected error in PostFeedbackJob: #{e.message}"
    Rails.logger.error error_msg
    Rails.logger.error e.backtrace.first(5).join("\n")
    { success: false, error: error_msg }
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