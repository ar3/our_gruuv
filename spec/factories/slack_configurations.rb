FactoryBot.define do
  factory :slack_configuration do
    association :organization, factory: :organization, type: 'Company'
    workspace_id { "T#{SecureRandom.hex(8).upcase}" }
    workspace_name { "test-workspace-#{SecureRandom.hex(4)}" }
    bot_token { "xoxb-#{SecureRandom.hex(32)}" }
    default_channel { "#general" }
    bot_username { "Huddle Bot" }
    bot_emoji { ":sparkles:" }
    installed_at { Time.current }
  end
end 