FactoryBot.define do
  factory :company_label_preference do
    association :company, factory: [:organization, :company]
    label_key { 'prompt' }
    label_value { nil }

    trait :with_custom_label do
      label_value { 'Reflection' }
    end
  end
end
