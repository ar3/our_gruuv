# frozen_string_literal: true

FactoryBot.define do
  factory :goal_association do
    associable factory: :assignment

    after(:build) do |ga|
      org = ga.associable.company
      ct = CompanyTeammate.find_by(organization_id: org.id) ||
           create(:company_teammate, organization: org)
      ga.goal ||= build(
        :goal,
        company_id: org.id,
        creator: ct,
        owner: ct,
        goal_type: 'inspirational_objective',
        most_likely_target_date: nil,
        earliest_target_date: nil,
        latest_target_date: nil
      )
    end
  end
end
