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

  it "completes the goal at 0% and 100_late" do
    started = create(:goal, owner: teammate, creator: teammate, company: company, title: "Active", started_at: 1.week.ago)

    result = described_class.call(
      goal: started,
      current_person: person,
      current_teammate: teammate,
      attrs: { confidence_percentage: "100_late", confidence_reason: "Done late" }
    )
    expect(result.ok?).to eq(true)
    expect(started.reload.completed_at).to be_present
    expect(started.goal_check_ins.first.confidence_percentage).to eq(100)

    started.update!(completed_at: nil)
    miss = described_class.call(
      goal: started,
      current_person: person,
      current_teammate: teammate,
      attrs: { confidence_percentage: "0", confidence_reason: "Missed" }
    )
    expect(miss.ok?).to eq(true)
    expect(started.reload.completed_at).to be_present
    expect(started.goal_check_ins.order(updated_at: :desc).first.confidence_percentage).to eq(0)
  end

  it "accepts string most_likely_target_date from the sheet alongside confidence (Date vs String)" do
    started = create(
      :goal,
      owner: teammate,
      creator: teammate,
      company: company,
      title: "Dated goal",
      started_at: 1.week.ago,
      earliest_target_date: Date.new(2026, 1, 1),
      most_likely_target_date: Date.new(2026, 6, 1),
      latest_target_date: Date.new(2026, 12, 1)
    )

    result = described_class.call(
      goal: started,
      current_person: person,
      current_teammate: teammate,
      attrs: {
        title: started.title,
        goal_type: started.goal_type,
        privacy_level: started.privacy_level,
        owner_id: "CompanyTeammate_#{teammate.id}",
        most_likely_target_date: "2026-06-01",
        confidence_percentage: "0",
        confidence_reason: "this is now done"
      }
    )

    expect(result.ok?).to eq(true), "expected success, got errors: #{result.errors.inspect}"
    expect(started.reload.completed_at).to be_present
    expect(started.most_likely_target_date).to eq(Date.new(2026, 6, 1))
  end
end
