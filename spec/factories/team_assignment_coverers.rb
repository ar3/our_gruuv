# frozen_string_literal: true

FactoryBot.define do
  factory :team_assignment_coverer do
    association :team_assignment_need

    company_teammate do
      association :company_teammate, organization: team_assignment_need.team.company
    end
  end
end
