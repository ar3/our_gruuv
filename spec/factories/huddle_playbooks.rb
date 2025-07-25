FactoryBot.define do
  factory :huddle_playbook do
    association :organization
    sequence(:special_session_name) { |n| "Sprint Planning #{n}" }
    slack_channel { nil }
  end
end 