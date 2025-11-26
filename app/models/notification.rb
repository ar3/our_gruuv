class Notification < ApplicationRecord
  belongs_to :notifiable, polymorphic: true
  belongs_to :main_thread, class_name: 'Notification', optional: true
  belongs_to :original_message, class_name: 'Notification', optional: true
  
  has_many :thread_replies, class_name: 'Notification', foreign_key: 'main_thread_id'
  has_many :message_edits, class_name: 'Notification', foreign_key: 'original_message_id'
  
  validates :notification_type, inclusion: { in: %w[huddle_announcement huddle_summary huddle_feedback observation_dm observation_channel test], allow_nil: true }
  validates :status, inclusion: { in: %w[preparing_to_send sent_successfully send_failed], allow_nil: true }
  
  scope :announcements, -> { where(notification_type: 'huddle_announcement') }
  scope :summaries, -> { where(notification_type: 'huddle_summary') }
  scope :feedbacks, -> { where(notification_type: 'huddle_feedback') }
  scope :successful, -> { where(status: 'sent_successfully') }
  scope :failed, -> { where(status: 'send_failed') }
  
  def slack_url
    return nil unless message_id.present? && metadata&.dig('channel').present?
    
    # Handle both cases: when notifiable is an organization (like Company) or has an organization/company
    slack_configuration = if notifiable.respond_to?(:calculated_slack_config)
      notifiable.calculated_slack_config
    elsif notifiable.respond_to?(:organization)
      notifiable.organization&.calculated_slack_config
    elsif notifiable.respond_to?(:company)
      notifiable.company&.calculated_slack_config
    else
      nil
    end
    
    return nil unless slack_configuration&.workspace_subdomain.present?
    
    channel_name = metadata['channel'].gsub('#', '')
    workspace_url = slack_configuration.workspace_url
    return nil unless workspace_url.present?
    
    "#{workspace_url}/archives/#{channel_name}/p#{message_id.gsub('.', '')}"
  end
  
  def is_main_thread?
    main_thread_id.nil?
  end
  
  def is_thread_reply?
    main_thread_id.present?
  end
  
  def is_edited_message?
    original_message_id.present?
  end
end 