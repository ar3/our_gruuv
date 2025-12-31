FactoryBot.define do
  factory :interest_submission do
    association :person
    thing_interested_in { "I'm interested in a new feature" }
    why_interested { "This would solve a problem for my team" }
    current_solution { "We currently use spreadsheets" }
    source_page { 'interest' }
    
    trait :minimal do
      thing_interested_in { nil }
      why_interested { nil }
      current_solution { nil }
    end
  end
end

