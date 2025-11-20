FactoryBot.define do
  factory :third_party_object do
    organization
    display_name { "general" }
    third_party_name { "general" }
    third_party_id { "C1234567890" }
    third_party_object_type { "channel" }
    third_party_source { "slack" }
    
    trait :slack_channel do
      third_party_object_type { "channel" }
      third_party_source { "slack" }
    end
    
    trait :slack_group do
      third_party_object_type { "group" }
      third_party_source { "slack" }
      third_party_id { "S1234567890" }
      display_name { "test-group" }
      third_party_name { "test-group" }
    end
  end
end 