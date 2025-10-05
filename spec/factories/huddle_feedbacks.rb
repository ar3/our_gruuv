FactoryBot.define do
  factory :huddle_feedback do
    association :huddle
    association :teammate
    informed_rating { rand(1..5) }
    connected_rating { rand(1..5) }
    goals_rating { rand(1..5) }
    valuable_rating { rand(1..5) }
    personal_conflict_style { %w[Collaborative Competing Compromising Accommodating Avoiding].sample }
    team_conflict_style { %w[Collaborative Competing Compromising Accommodating Avoiding].sample }
    appreciation { "Great meeting!" }
    change_suggestion { "More time for discussion" }
    private_department_head { nil }
    private_facilitator { nil }
    anonymous { false }
  end
end 