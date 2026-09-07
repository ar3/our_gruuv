# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::BulkEditUpdate do
  let(:company) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil)
  end
  let(:goal) do
    create(:goal, :draft, owner: teammate, creator: teammate, company: company, title: "Draft goal")
  end

  it "updates title without starting the goal" do
    result = described_class.call(
      goal: goal,
      current_person: person,
      current_teammate: teammate,
      attrs: { title: "Renamed draft" }
    )

    expect(result.ok?).to eq(true)
    expect(goal.reload.title).to eq("Renamed draft")
    expect(goal.started_at).to be_nil
  end

  it "updates privacy level" do
    result = described_class.call(
      goal: goal,
      current_person: person,
      current_teammate: teammate,
      attrs: { privacy_level: "everyone_in_company" }
    )

    expect(result.ok?).to eq(true)
    expect(goal.reload.privacy_level).to eq("everyone_in_company")
  end

  it "starts the goal when confidence is set" do
    result = described_class.call(
      goal: goal,
      current_person: person,
      current_teammate: teammate,
      attrs: { confidence_percentage: 70, confidence_reason: "On track" }
    )

    expect(result.ok?).to eq(true)
    goal.reload
    expect(goal.started_at).to be_present
    expect(goal.goal_check_ins.count).to eq(1)
    expect(goal.goal_check_ins.first.confidence_percentage).to eq(70)
  end
end
