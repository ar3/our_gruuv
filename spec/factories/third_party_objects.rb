FactoryBot.define do
  factory :third_party_object do
    organization
    display_name { "general" }
    third_party_name { "general" }
    third_party_id { "C1234567890" }
    third_party_object_type { "channel" }
    third_party_source { "slack" }
  end
end 