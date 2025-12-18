FactoryBot.define do
  factory :prompt_question do
    association :prompt_template
    label { "What are your main goals this quarter?" }
    placeholder_text { "Enter your goals here..." }
    helper_text { "Think about what you want to accomplish" }
    position { 1 }
  end
end


