# frozen_string_literal: true

require "rails_helper"

RSpec.describe TalentDensity::TeammateInfoBuilder do
  let(:company) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:ic) { create(:company_teammate, :assigned_employee, organization: company, first_employed_at: Date.new(2024, 1, 15)) }

  it "builds employed since, position change, target, goals, and experiences summary" do
    old_tenure = create(
      :employment_tenure,
      company_teammate: ic,
      company: company,
      manager_teammate: manager,
      started_at: Time.zone.parse("2024-01-15"),
      ended_at: Time.zone.parse("2025-06-01")
    )
    new_tenure = create(
      :employment_tenure,
      company_teammate: ic,
      company: company,
      manager_teammate: manager,
      started_at: Time.zone.parse("2025-06-01"),
      ended_at: nil
    )
    title = create(:title, company: company)
    target = create(:position, title: title, position_level: create(:position_level, position_major_level: title.position_major_level))
    ic.update!(next_goal_position: target)

    assignment = create(:assignment, company: company)
    goal = create(
      :goal,
      owner: ic,
      creator: ic,
      most_likely_target_date: Date.new(2026, 12, 1)
    )
    create(:goal_association, goal: goal, associable: assignment)

    create(
      :position_check_in,
      :closed,
      teammate: ic,
      employment_tenure: new_tenure,
      official_rating: 2,
      official_check_in_completed_at: Time.zone.parse("2026-03-01")
    )

    info = described_class.call(teammates: [ic.reload], company: company)[ic.id]

    expect(info.employed_since_at.to_date).to eq(Date.new(2024, 1, 15))
    expect(info.position_change_at.to_date).to eq(Date.new(2025, 6, 1))
    expect(info.from_position).to eq(old_tenure.position)
    expect(info.to_position).to eq(new_tenure.position)
    expect(info.target_position).to eq(target)
    expect(info.active_goals_count).to eq(1)
    expect(info.active_goals_latest_completion_date).to eq(Date.new(2026, 12, 1))
    expect(info.latest_finalized_check_in).to be_present
    expect(info.experiences_summary).to be_a(MyGrowth::ExperiencesSummary)
  end
end
