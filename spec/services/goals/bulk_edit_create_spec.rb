# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::BulkEditCreate do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end

  it "creates a draft goal with title, owner, and type" do
    result = described_class.call(
      organization: company,
      current_person: person,
      current_teammate: teammate,
      attrs: {
        title: "Sheet goal",
        goal_type: "quantitative_key_result",
        owner_id: "CompanyTeammate_#{teammate.id}"
      }
    )

    expect(result.ok?).to eq(true)
    expect(result.goal).to be_persisted
    expect(result.goal.title).to eq("Sheet goal")
    expect(result.goal.started_at).to be_nil
    expect(result.goal.owner).to eq(teammate)
  end

  it "links a child under a parent goal" do
    parent = create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Parent")

    result = described_class.call(
      organization: company,
      current_person: person,
      current_teammate: teammate,
      attrs: {
        title: "Child",
        goal_type: "stepping_stone_activity",
        owner_id: "CompanyTeammate_#{teammate.id}"
      },
      parent_goal: parent
    )

    expect(result.ok?).to eq(true)
    expect(GoalLink.exists?(parent_id: parent.id, child_id: result.goal.id)).to eq(true)
  end
end
