# frozen_string_literal: true

require "rails_helper"

RSpec.describe ValuesHealth::ExpectationAlignmentOverview do
  let(:organization) { create(:organization, :company) }
  let(:reference_time) { Time.zone.parse("2026-09-04 12:00:00") }

  def create_score!(aspiration, score:, calculated_at:)
    AspirationExpectationAlignmentScore.create!(
      aspiration: aspiration,
      organization: organization,
      score: score,
      cells: [],
      check_in_teammate_count: 2,
      calculated_at: calculated_at
    )
  end

  it "summarizes distribution, best/worst, and refreshable rows for active values" do
    best = create(:aspiration, company: organization, name: "Best Value", sort_order: 1)
    mid = create(:aspiration, company: organization, name: "Mid Value", sort_order: 2)
    worst = create(:aspiration, company: organization, name: "Worst Value", sort_order: 3)
    missing = create(:aspiration, company: organization, name: "Missing Score", sort_order: 4)
    deleted = create(:aspiration, company: organization, name: "Deleted Value", sort_order: 5)
    deleted.soft_delete!

    create_score!(best, score: 96, calculated_at: reference_time - 1.hour)
    create_score!(mid, score: 70, calculated_at: reference_time - 2.days)
    create_score!(worst, score: 20, calculated_at: reference_time - 1.hour)

    result = described_class.new(organization: organization, reference_time: reference_time).call

    expect(result.total_count).to eq(4)
    expect(result.scored_count).to eq(3)
    expect(result.missing_count).to eq(1)
    expect(result.stale_count).to eq(1)
    expect(result.refreshable_count).to eq(2)
    expect(result.average_score).to eq(62.0)
    expect(result.best.map { |row| row.aspiration.id }).to eq([best.id, mid.id, worst.id])
    expect(result.worst.map { |row| row.aspiration.id }).to eq([worst.id, mid.id, best.id])
    expect(result.refreshable_aspiration_ids).to contain_exactly(missing.id, mid.id)
    expect(result.chart_data[:categories]).to include("Strongly Aligned", "Slightly Aligned", "Strongly Mis-aligned", "No score")
    strongly_aligned = result.distribution.find { |bucket| bucket[:key] == :strongly_aligned }
    expect(strongly_aligned[:count]).to eq(1)
  end
end
