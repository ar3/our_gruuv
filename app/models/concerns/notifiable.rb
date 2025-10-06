module Notifiable
  extend ActiveSupport::Concern

  included do
    has_many :notifications, as: :notifiable, dependent: :destroy
  end

  def successful_notifications(sub_type: nil)
    query = notifications.where(status: 'sent_successfully')
    query = query.where(notification_type: sub_type) if sub_type
    query.order(:created_at)
  end

  def last_successful_notification(sub_type: nil)
    successful_notifications(sub_type: sub_type).last
  end

  def posted_to_slack?(sub_type: nil)
    successful_notifications(sub_type: sub_type).exists?
  end

  def original_notifications
    notifications.where(original_message_id: nil)
  end

  def notification_edits
    notifications.where.not(original_message_id: nil)
  end

  def has_notification_edits?
    notification_edits.exists?
  end

  def latest_notification_version(sub_type: nil)
    original_notification = original_notifications.where(notification_type: sub_type).first
    return nil unless original_notification

    latest_edit = notification_edits
                    .where(original_message_id: original_notification.id)
                    .order(created_at: :desc)
                    .first

    latest_edit || original_notification
  end

  def notification_history(sub_type: nil)
    original_notification = original_notifications.where(notification_type: sub_type).first
    return [] unless original_notification

    Notification
      .where(id: original_notification.id)
      .or(Notification.where(original_message_id: original_notification.id))
      .order(:created_at)
  end

  def post_to_slack!(sub_type: nil, **options)
    # This will be implemented when we create the PostNotificationJob
    # For now, just raise an error to indicate it needs to be implemented
    raise NotImplementedError, "post_to_slack! will be implemented in Observations::PostNotificationJob"
  end

  def can_post_to_slack?
    # Basic check - can be overridden by including models
    respond_to?(:company) && company.present?
  end

  def slack_notification_context
    # Default context - can be overridden by including models
    {
      notifiable_type: self.class.name,
      notifiable_id: id
    }
  end
end
