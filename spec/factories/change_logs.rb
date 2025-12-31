FactoryBot.define do
  factory :change_log do
    launched_on { Date.today }
    description { "This is a test change log description with **markdown** support." }
    change_type { 'new_value' }
    image_url { nil }
    
    trait :major_enhancement do
      change_type { 'major_enhancement' }
    end
    
    trait :minor_enhancement do
      change_type { 'minor_enhancement' }
    end
    
    trait :bug_fix do
      change_type { 'bug_fix' }
    end
    
    trait :with_image do
      image_url { 'https://example.com/image.png' }
    end
    
    trait :past_90_days do
      launched_on { 30.days.ago.to_date }
    end
  end
end

