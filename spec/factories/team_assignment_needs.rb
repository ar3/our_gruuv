# frozen_string_literal: true

FactoryBot.define do
  factory :team_assignment_need do
    association :team
    need_type { "required" }

    assignment do
      association :assignment, company: team.company
    end

    trait :nice_to_have do
      need_type { "nice_to_have" }
    end
  end
end
