class Huddles::PostSummaryJob < ApplicationJob
  queue_as :default

  def perform(huddle_id)
    huddle = Huddle.find(huddle_id)
    
    # Check if Slack is configured for this organization
    unless huddle.slack_configured?
      result = { success: false, error: "Slack not configured for organization #{huddle.organization&.id}" }
      Rails.logger.info "Slack not configured for organization #{huddle.organization&.id}, skipping summary"
      return result
    end
    
    # Ensure announcement exists first
    announcement_notification = huddle.slack_announcement_notification
    
    if announcement_notification.nil?
      # Create announcement first
      Huddles::PostAnnouncementJob.perform_now(huddle_id)
      announcement_notification = huddle.reload.slack_announcement_notification
    end
    
    # Check if summary already exists
    existing_summary = huddle.notifications.summaries.successful.first
    
    if existing_summary
      # Create new notification for update
      blocks = build_summary_blocks(huddle, is_thread: true)
      notification = huddle.notifications.create!(
        notification_type: 'huddle_summary',
        original_message: existing_summary,
        status: 'preparing_to_send',
        metadata: { channel: huddle.slack_channel },
        rich_message: blocks,
        fallback_text: build_summary_fallback_text(huddle)
      )
      
      Rails.logger.info "Updating existing summary for huddle #{huddle.id}"
      
      # Update the existing message
      result = SlackService.new(huddle.organization).update_message(notification.id)
      
      if result[:success]
        { success: true, action: 'updated_summary', huddle_id: huddle.id, notification_id: notification.id, message_id: result[:message_id] }
      else
        { success: false, action: 'update_summary_failed', huddle_id: huddle.id, notification_id: notification.id, error: result[:error] }
      end
    else
      # Create new summary notification
      blocks = build_summary_blocks(huddle, is_thread: true)
      notification = huddle.notifications.create!(
        notification_type: 'huddle_summary',
        main_thread: announcement_notification,
        status: 'preparing_to_send',
        metadata: { channel: huddle.slack_channel },
        rich_message: blocks,
        fallback_text: build_summary_fallback_text(huddle)
      )
      
      Rails.logger.info "Creating new summary for huddle #{huddle.id}"
      
      # Post new message in thread
      result = SlackService.new(huddle.organization).post_message(notification.id)
      
      if result[:success]
        { success: true, action: 'posted_summary', huddle_id: huddle.id, notification_id: notification.id, message_id: result[:message_id] }
      else
        { success: false, action: 'post_summary_failed', huddle_id: huddle.id, notification_id: notification.id, error: result[:error] }
      end
    end
  rescue ActiveRecord::RecordNotFound => e
    error_msg = "Huddle with ID #{huddle_id} not found"
    Rails.logger.error error_msg
    { success: false, error: error_msg }
  rescue => e
    error_msg = "Unexpected error in PostSummaryJob: #{e.message}"
    Rails.logger.error error_msg
    Rails.logger.error e.backtrace.first(5).join("\n")
    { success: false, error: error_msg }
  end

  private

  def feedback_huddle_url(huddle)
    Rails.application.routes.url_helpers.feedback_huddle_url(huddle)
  end

  def build_summary_fallback_text(huddle)
    "📊 Huddle Summary - Participation: #{huddle.huddle_feedbacks.count}/#{huddle.huddle_participants.count} participants • Nat 20 Score: #{huddle.nat_20_score || 'N/A'} • Average Ratings: Informed: #{huddle.average_rating_by_category[:informed] || 'N/A'}/5, Connected: #{huddle.average_rating_by_category[:connected] || 'N/A'}/5, Goals: #{huddle.average_rating_by_category[:goals] || 'N/A'}/5, Valuable: #{huddle.average_rating_by_category[:valuable] || 'N/A'}/5 • Insights: #{huddle.feedback_insights.first(2).join(', ') || 'No insights yet'}"
  end

  def build_summary_blocks(huddle, is_thread: false)
    if is_thread
      # Detailed summary for thread
      blocks = [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "📊 Huddle Summary",
            emoji: true
          }
        },
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: "*Participation:*\n#{huddle.huddle_feedbacks.count}/#{huddle.huddle_participants.count} participants"
            },
            {
              type: "mrkdwn",
              text: "*Nat 20 Score:*\n#{huddle.nat_20_score || 'N/A'}"
            }
          ]
        },
        {
          type: "section",
          fields: [
            {
              type: "mrkdwn",
              text: "*Average Ratings:*\n• Informed: #{huddle.average_rating_by_category[:informed] || 'N/A'}/5\n• Connected: #{huddle.average_rating_by_category[:connected] || 'N/A'}/5\n• Goals: #{huddle.average_rating_by_category[:goals] || 'N/A'}/5\n• Valuable: #{huddle.average_rating_by_category[:valuable] || 'N/A'}/5"
            },
            {
              type: "mrkdwn",
              text: "*Insights:*\n#{huddle.feedback_insights.first(2).join("\n") || 'No insights yet'}"
            }
          ]
        }
      ]
      
      # Add feedback link if at least one person has submitted feedback
      if huddle.huddle_feedbacks.any?
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "💬 *Want to contribute?* <#{feedback_huddle_url(huddle)}|Submit your feedback>"
          }
        }
      end
      
      blocks
    else
      # Main announcement
      blocks = [
        {
          type: "header",
          text: {
            type: "plain_text",
            text: "🎯 #{huddle.display_name} - Summary Available",
            emoji: true
          }
        },
        {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "The huddle summary is now available! Check the thread below for detailed insights and feedback highlights."
          }
        },
        {
          type: "context",
          elements: [
            {
              type: "mrkdwn",
              text: "📈 #{huddle.huddle_feedbacks.count}/#{huddle.huddle_participants.count} participants submitted feedback • Nat 20 Score: #{huddle.nat_20_score || 'N/A'}"
            }
          ]
        }
      ]
      
      # Add feedback link if at least one person has submitted feedback
      if huddle.huddle_feedbacks.any?
        blocks << {
          type: "section",
          text: {
            type: "mrkdwn",
            text: "💬 *Want to contribute?* <#{feedback_huddle_url(huddle)}|Submit your feedback>"
          }
        }
      end
      
      blocks
    end
  end
end 