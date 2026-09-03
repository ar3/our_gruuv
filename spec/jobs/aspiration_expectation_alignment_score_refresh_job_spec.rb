# frozen_string_literal: true

require "rails_helper"

RSpec.describe AspirationExpectationAlignmentScoreRefreshJob, type: :job do
  let(:organization) { create(:organization) }
  let(:aspiration) { create(:aspiration, company: organization) }

  it "persists the values expectation alignment score" do
    teammate = create(:teammate, :assigned_employee, organization: organization)
    create(:employment_tenure, company_teammate: teammate, company: organization)
    create(
      :aspiration_check_in,
      :finalized,
      teammate: teammate,
      aspiration: aspiration,
      employee_rating: "meeting",
      manager_rating: "meeting"
    )

    expect {
      described_class.perform_now(aspiration.id)
    }.to change(AspirationExpectationAlignmentScore, :count).by(1)

    expect(aspiration.reload.expectation_alignment_score_cache.score.to_f).to eq(100.0)
  end
end

RSpec.describe DailyRefreshAspirationExpectationAlignmentScoresJob, type: :job do
  let(:organization) { create(:organization) }
  let(:aspiration) { create(:aspiration, company: organization) }

  it "enqueues a refresh for each persisted score row" do
    AspirationExpectationAlignmentScore.create!(
      aspiration: aspiration,
      organization: organization,
      score: 50,
      cells: [],
      check_in_teammate_count: 2,
      calculated_at: 1.day.ago
    )

    expect {
      described_class.perform_now
    }.to have_enqueued_job(AspirationExpectationAlignmentScoreRefreshJob).with(aspiration.id)
  end
end
