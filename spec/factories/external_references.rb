FactoryBot.define do
  factory :external_reference do
    url { "https://docs.google.com/document/d/example" }
    reference_type { "published" }
    association :referable, factory: :assignment
    
    trait :draft do
      reference_type { "draft" }
    end
    
    trait :published do
      reference_type { "published" }
    end
  end
end 