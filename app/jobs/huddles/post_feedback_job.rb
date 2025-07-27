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
    parts = ["💬 New Feedback from #{feedback.display_name}"]
    parts << "Nat 20 Score: #{feedback.nat_20_score}/20"
    parts << "Ratings: I:#{feedback.informed_rating} C:#{feedback.connected_rating} G:#{feedback.goals_rating} V:#{feedback.valuable_rating}"
    parts << "Appreciation: #{feedback.appreciation}" if feedback.appreciation.present?
    parts << "Change Suggestion: #{feedback.change_suggestion}" if feedback.change_suggestion.present?
    
    conflict_parts = []
    conflict_parts << "Personal: #{feedback.personal_conflict_style}" if feedback.personal_conflict_style.present?
    conflict_parts << "Team: #{feedback.team_conflict_style}" if feedback.team_conflict_style.present?
    parts << "Conflict Styles: #{conflict_parts.join(', ')}" if conflict_parts.any?
    
    parts.join(' • ')
  end

  def build_feedback_blocks(feedback)
    blocks = [
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
            text: "*Nat 20 Score:*\n#{feedback.nat_20_score}/20"
          },
          {
            type: "mrkdwn",
            text: "*Ratings:*\n• Informed: #{feedback.informed_rating}/5\n• Connected: #{feedback.connected_rating}/5\n• Goals: #{feedback.goals_rating}/5\n• Valuable: #{feedback.valuable_rating}/5"
          }
        ]
      }
    ]
    
    # Add appreciation if present
    if feedback.appreciation.present?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*🙏 Appreciation:*\n#{feedback.appreciation}"
        }
      }
    end
    
    # Add change suggestion if present
    if feedback.change_suggestion.present?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*💡 Change Suggestion:*\n#{feedback.change_suggestion}"
        }
      }
    end
    
    # Add conflict styles if present
    conflict_styles = []
    conflict_styles << "Personal: #{feedback.personal_conflict_style}" if feedback.personal_conflict_style.present?
    conflict_styles << "Team: #{feedback.team_conflict_style}" if feedback.team_conflict_style.present?
    
    if conflict_styles.any?
      blocks << {
        type: "section",
        text: {
          type: "mrkdwn",
          text: "*⚔️ Conflict Styles:*\n#{conflict_styles.join(' • ')}"
        }
      }
    end
    
    blocks
  end
end 