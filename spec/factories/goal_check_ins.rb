FactoryBot.define do
  factory :goal_check_in do
    association :goal
    association :confidence_reporter, factory: :person
    check_in_week_start { Date.current.beginning_of_week(:monday) }
    confidence_percentage { 75 }
    confidence_reason { "Making good progress" }
  end
end

