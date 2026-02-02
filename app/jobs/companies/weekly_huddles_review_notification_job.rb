class Companies::WeeklyHuddlesReviewNotificationJob < ApplicationJob
  queue_as :default

  def perform(company_id)
    begin
      company = Organization.find(company_id)
      
      unless company.slack_configured?
        return { success: false, error: 'Slack is not configured for this company' }
      end
      
      unless company.huddle_review_notification_channel
        return { success: false, error: 'Huddle review notification channel is not configured' }
      end

      # Get feedback stats for the past week using the service
      stats_service = Huddles::WeeklyStatsService.new(company)
      feedback_stats = stats_service.weekly_feedback_stats
      
      # Build the message
      message = build_message(company, feedback_stats)
      
      # Check if a notification already exists for this week
      week_start = Date.current.beginning_of_week(:monday)
      existing_notification = Notification.where(
        notifiable: company,
        notification_type: 'huddle_summary',
        created_at: week_start..week_start.end_of_week
      ).first

      if existing_notification
        # Create a new notification record linked to the original
        notification = Notification.create!(
          notifiable: company,
          notification_type: 'huddle_summary',
          status: 'preparing_to_send',
          original_message_id: existing_notification.id,
          metadata: { 
            channel: company.huddle_review_notification_channel.third_party_id,
            notifiable_type: 'Organization',
            notifiable_id: company.id
          },
          rich_message: message[:blocks],
          fallback_text: message[:text]
        )
            
        # Send to Slack (update existing message)
        slack_service = SlackService.new(company)
        slack_service.update_message(notification.id)
      else
        # Create a new notification record
        notification = Notification.create!(
          notifiable: company,
          notification_type: 'huddle_summary',
          status: 'preparing_to_send',
          metadata: { 
            channel: company.huddle_review_notification_channel.third_party_id,
            notifiable_type: 'Organization',
            notifiable_id: company.id
          },
          rich_message: message[:blocks],
          fallback_text: message[:text]
        )
            
        # Send to Slack
        slack_service = SlackService.new(company)
        slack_service.post_message(notification.id)
      end
      
      { success: true, error: nil }
      
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Company not found: #{company_id}"
      { success: false, error: "Company not found" }
    rescue => e
      # Log the error and return failure
      Rails.logger.error "Weekly huddles review notification failed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end

  private

  def build_message(company, stats)
    text = "📊 *Weekly Huddles Health Report*\n"
    text += "Week of #{stats[:start_date].strftime('%B %d')} - #{stats[:end_date].strftime('%B %d, %Y')}\n\n"
    text += "🤝 *#{stats[:huddle_count]} huddles* were started this week\n"
    text += "👥 *#{stats[:distinct_participants]} distinct participants* joined huddles\n"
    text += "⭐ *Average rating: #{stats[:average_rating]}/20*\n"
    text += "📝 *Feedback participation rate: #{stats[:participation_rate]}%*\n"
    text += "🤝 *Collaborative team conflict style: #{stats[:collaborative_percentage]}%*\n"
    text += "💬 *#{stats[:positive_constructive_count]} pieces of positive and constructive feedback* were shared\n\n"
    text += "Every piece of feedback helps us improve our meetings! 💪"

    blocks = [
      {
        type: "header",
        text: {
          type: "plain_text",
          text: "📊 Weekly Huddles Health Report",
          emoji: true
        }
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "Week of #{stats[:start_date].strftime('%B %d')} - #{stats[:end_date].strftime('%B %d, %Y')}"
        }
      },
      {
        type: "divider"
      },
      {
        type: "section",
        fields: [
          {
            type: "mrkdwn",
            text: "*🤝 Huddles started this week:*\n#{stats[:huddle_count]}"
          },
          {
            type: "mrkdwn",
            text: "*👥 Distinct participants:*\n#{stats[:distinct_participants]}"
          },
          {
            type: "mrkdwn",
            text: "*⭐ Average rating:*\n#{stats[:average_rating]}/20"
          },
          {
            type: "mrkdwn",
            text: "*📝 Feedback participation rate:*\n#{stats[:participation_rate]}%"
          },
          {
            type: "mrkdwn",
            text: "*🤝 Collaborative team conflict style:*\n#{stats[:collaborative_percentage]}%"
          },
          {
            type: "mrkdwn",
            text: "*💬 Positive and constructive feedback:*\n#{stats[:positive_constructive_count]} pieces"
          }
        ]
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "Every piece of feedback helps us improve our meetings! 💪"
        }
      },
      {
        type: "divider"
      },
      {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "Want to see more details? Check out your <#{huddles_review_url(company)}|Huddles Review>"
        }
      }
    ]

    { text: text, blocks: blocks }
  end

  def huddles_review_url(company)
    Rails.application.routes.url_helpers.huddles_review_organization_url(company)
  end
end
