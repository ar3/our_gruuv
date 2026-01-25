FactoryBot.define do
  factory :feedback_request_question do
    association :feedback_request
    question_text { "What did you observe about this person? #{rand(1000)}" }
    position { 1 }
    rateable_type { nil }
    rateable_id { nil }

    trait :with_blank_text do
      question_text { '' }
    end

    trait :second_question do
      question_text { "What could be improved? #{rand(1000)}" }
      position { 2 }
    end

    trait :third_question do
      question_text { "Any additional thoughts? #{rand(1000)}" }
      position { 3 }
    end

    trait :with_assignment do
      association :rateable, factory: :assignment
      
      after(:build) do |question|
        question.rateable.company = question.feedback_request.company if question.rateable
      end
    end

    trait :with_ability do
      association :rateable, factory: :ability
      
      after(:build) do |question|
        question.rateable.organization = question.feedback_request.company if question.rateable
      end
    end

    trait :with_aspiration do
      association :rateable, factory: :aspiration
      
      after(:build) do |question|
        question.rateable.organization = question.feedback_request.company if question.rateable
      end
    end
  end
end
