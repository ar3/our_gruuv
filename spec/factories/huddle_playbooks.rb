FactoryBot.define do
  factory :huddle_playbook do
    association :organization
    instruction_alias { "Sprint Planning" }
    slack_channel { nil }
  end
end 