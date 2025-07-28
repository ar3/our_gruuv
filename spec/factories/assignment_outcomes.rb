FactoryBot.define do
  factory :assignment_outcome do
    description { "Users report 90% satisfaction with product features" }
    association :assignment
  end
end 