FactoryBot.define do
  factory :third_party_object_association do
    third_party_object
    association :associatable, factory: :company
    association_type { "huddle_review_notification_channel" }
  end
end 