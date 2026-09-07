# frozen_string_literal: true

require "rails_helper"

RSpec.describe TeamsHealth::Summary do
  let(:company) { create(:organization, :company) }
  let(:creator) { create(:teammate, organization: company) }

  it "counts active teams by Goal Confidence status using Team-owned goals" do
    healthy_team = create(:team, company: company, name: "Healthy")
    empty_team = create(:team, company: company, name: "Empty")
    create(:team, company: company, name: "Archived", deleted_at: Time.current)

    goal = create(
      :goal,
      :with_team_owner,
      owner: healthy_team,
      creator: creator,
      company: company,
      started_at: 1.week.ago
    )
    create(:goal_check_in, goal: goal, confidence_reporter: creator.person, updated_at: 2.days.ago)

    result = described_class.new(organization: company).call

    expect(result.total_teams).to eq(2)
    expect(result.healthy_count).to eq(1)
    expect(result.needs_attention_count).to eq(1)
    expect(result.warning_count).to eq(0)
    expect(empty_team).to be_present
  end
end
