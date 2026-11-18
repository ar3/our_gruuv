# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::RecordOg3DefaultCheck, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:goal) do
    create(
      :goal,
      creator: teammate,
      owner: teammate,
      company: organization,
      goal_type: "quantitative_key_result",
      title: "Grow from 10 to 20",
      started_at: nil
    )
  end

  it "persists a PaperTrail-tracked check result on the goal" do
    expect do
      described_class.persist!(
        goal: goal,
        status: "skipped_title_unchanged",
        summary: "Title did not change.",
        details: { reasons: "n/a" }
      )
    end.to change { goal.reload.versions.count }.by(1)

    expect(goal.og3_default_check_result).to include("status=skipped_title_unchanged")
    expect(goal.og3_default_check_result).to include("Title did not change.")
    expect(goal.og3_default_check_result).to include("reasons: n/a")
  end
end
