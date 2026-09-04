# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssignmentsHealth::ExpectationAlignmentOverview do
  let(:organization) { create(:organization, :company) }
  let(:reference_time) { Time.zone.parse("2026-09-04 12:00:00") }

  def create_score!(assignment, score:, calculated_at:)
    AssignmentExpectationAlignmentScore.create!(
      assignment: assignment,
      organization: organization,
      score: score,
      cells: [],
      check_in_teammate_count: 2,
      survey_respondent_count: 2,
      calculated_at: calculated_at
    )
  end

  it "summarizes distribution, best/worst, and refreshable rows for non-archived assignments" do
    best = create(:assignment, company: organization, title: "Best Assignment")
    mid = create(:assignment, company: organization, title: "Mid Assignment")
    worst = create(:assignment, company: organization, title: "Worst Assignment")
    missing = create(:assignment, company: organization, title: "Missing Score")
    archived = create(:assignment, company: organization, title: "Archived")
    archived.update!(deleted_at: 1.day.ago)

    create_score!(best, score: 96, calculated_at: reference_time - 1.hour)
    create_score!(mid, score: 70, calculated_at: reference_time - 2.days)
    create_score!(worst, score: 20, calculated_at: reference_time - 1.hour)
    create_score!(archived, score: 10, calculated_at: reference_time - 1.hour)

    result = described_class.new(organization: organization, reference_time: reference_time).call

    expect(result.total_count).to eq(4)
    expect(result.scored_count).to eq(3)
    expect(result.missing_count).to eq(1)
    expect(result.stale_count).to eq(1)
    expect(result.refreshable_count).to eq(2)
    expect(result.average_score).to eq(62.0)
    expect(result.best.map { |row| row.assignment.id }).to eq([best.id, mid.id, worst.id])
    expect(result.worst.map { |row| row.assignment.id }).to eq([worst.id, mid.id, best.id])
    expect(result.refreshable_assignment_ids).to contain_exactly(missing.id, mid.id)
    expect(result.chart_data[:categories]).to include("Great", "Slightly Good", "Worst", "No score")
    incredible = result.distribution.find { |bucket| bucket[:key] == :incredible }
    expect(incredible[:count]).to eq(1)
  end
end
