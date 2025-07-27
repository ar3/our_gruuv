FactoryBot.define do
  factory :notification do
    association :notifiable, factory: :huddle
    notification_type { 'huddle_announcement' }
    status { 'sent_successfully' }
    message_id { '1234567890.123456' }
    metadata { { channel: 'general' } }
    rich_message { [{ type: 'section', text: { type: 'mrkdwn', text: 'Test message' } }] }
    fallback_text { 'Test message' }
    
    trait :huddle_announcement do
      notification_type { 'huddle_announcement' }
    end
    
    trait :huddle_summary do
      notification_type { 'huddle_summary' }
    end
    
    trait :huddle_feedback do
      notification_type { 'huddle_feedback' }
    end
    
    trait :preparing_to_send do
      status { 'preparing_to_send' }
    end
    
    trait :send_failed do
      status { 'send_failed' }
    end
  end
end 