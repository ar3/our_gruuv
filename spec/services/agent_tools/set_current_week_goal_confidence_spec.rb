# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::SetCurrentWeekGoalConfidence, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:current_monday) { Date.current.beginning_of_week(:monday) }
  let(:goal) do
    create(
      :goal,
      creator: teammate,
      owner: teammate,
      company: organization,
      most_likely_target_date: Date.today + 1.month
    )
  end
  let(:context) do
    AgentTools::Context.new(
      organization: organization,
      person: person,
      company_teammate: teammate
    )
  end
  let(:goal_path) { AgentTools::RecordPaths.goal_path(context, goal) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
  end

  it "upserts confidence for the current Monday week" do
    result = described_class.call(
      context: context,
      goal_path: goal_path,
      confidence_percentage: 70,
      confidence_reason: "On track"
    )

    expect(result.ok?).to be(true)
    check_in = goal.goal_check_ins.find_by!(check_in_week_start: current_monday)
    expect(check_in.confidence_percentage).to eq(70)
    expect(check_in.confidence_reason).to eq("On track")
    expect(result.data[:week_start]).to eq(current_monday.iso8601)
    expect(result.data[:path]).to be_present
  end

  it "rejects a non-current week_start" do
    result = described_class.call(
      context: context,
      goal_path: goal_path,
      confidence_percentage: 50,
      week_start: current_monday - 7.days
    )

    expect(result.ok?).to be(false)
    expect(result.error).to include("current week")
    expect(goal.goal_check_ins.count).to eq(0)
  end

  it "rejects a completed goal" do
    goal.update!(completed_at: Time.current)

    result = described_class.call(
      context: context,
      goal_path: goal_path,
      confidence_percentage: 80
    )

    expect(result.ok?).to be(false)
    expect(result.error).to include("completed")
    expect(goal.goal_check_ins.count).to eq(0)
  end

  it "rejects 0% or 100% without learnings" do
    result = described_class.call(
      context: context,
      goal_path: goal_path,
      confidence_percentage: 100
    )

    expect(result.ok?).to be(false)
    expect(result.error).to include("learnings")
    expect(goal.reload.completed_at).to be_nil
  end

  it "allows completing at 100% when learnings are provided" do
    result = described_class.call(
      context: context,
      goal_path: goal_path,
      confidence_percentage: 100,
      learnings: "We shipped it and learned to scope earlier."
    )

    expect(result.ok?).to be(true)
    expect(goal.reload.completed_at).to be_present
    expect(goal.goal_check_ins.find_by!(check_in_week_start: current_monday).confidence_reason)
      .to eq("We shipped it and learned to scope earlier.")
  end

  it "ignores client week_start when it matches current Monday" do
    result = described_class.call(
      context: context,
      goal_path: goal_path,
      confidence_percentage: 40,
      week_start: current_monday
    )

    expect(result.ok?).to be(true)
    expect(goal.goal_check_ins.find_by!(check_in_week_start: current_monday).confidence_percentage).to eq(40)
  end
end
