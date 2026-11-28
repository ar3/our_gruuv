# frozen_string_literal: true

FactoryBot.define do
  factory :team_primary_outcome do
    association :team

    assignment_outcome do
      assignment = create(:assignment, company: team.company)
      create(:team_assignment_need, team: team, assignment: assignment)
      create(:assignment_outcome, assignment: assignment)
    end
  end
end
