class SlackNotificationJob < ApplicationJob
  queue_as :default

  def perform(huddle_id, notification_type, **options)
    huddle = Huddle.find(huddle_id)
    slack_service = SlackService.new(huddle.organization)
    
    Rails.logger.info "Slack: Sending #{notification_type} notification for huddle #{huddle.id}"
    
    result = slack_service.post_huddle_notification(huddle, notification_type, **options)
    
    if result
      Rails.logger.info "Slack: #{notification_type} notification sent successfully for huddle #{huddle.id}"
    else
      Rails.logger.error "Slack: Failed to send #{notification_type} notification for huddle #{huddle.id}"
    end
    
    result
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "Slack: Huddle #{huddle_id} not found for #{notification_type} notification"
    false
  rescue => e
    Rails.logger.error "Slack: Error sending #{notification_type} notification for huddle #{huddle_id}: #{e.message}"
    false
  end
end 