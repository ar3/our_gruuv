# frozen_string_literal: true

require "rails_helper"

RSpec.describe AssignmentSurveys::InsightsAnalytics do
  let(:organization) { create(:organization, :company) }
  let(:chart_range) { 8.weeks.ago..Time.current }

  let!(:active_teammate) do
    create(:teammate, :assigned_employee, organization: organization, first_employed_at: 2.months.ago)
  end
  let!(:other_active_teammate) do
    create(:teammate, :assigned_employee, organization: organization, first_employed_at: 2.months.ago)
  end
  let!(:held_assignment) { create(:assignment, company: organization, title: "Held assignment") }
  let!(:catalog_only_assignment) { create(:assignment, company: organization, title: "Catalog only") }

  before do
    create(:employment_tenure, company_teammate: active_teammate, company: organization)
    create(:employment_tenure, company_teammate: other_active_teammate, company: organization)
    create(:assignment_tenure, teammate: active_teammate, assignment: held_assignment)
  end

  def create_submitted!(attrs = {})
    create(
      :assignment_survey_response,
      {
        company_teammate: active_teammate,
        assignment: held_assignment,
        understandable_rating: 5,
        submitted_at: 1.week.ago
      }.merge(attrs)
    )
  end

  subject(:result) do
    described_class.new(organization: organization, chart_range: chart_range).call
  end

  it "counts active teammates who ever submitted vs never" do
    create_submitted!(personal_alignment: "like")

    expect(result.active_teammate_count).to eq(2)
    expect(result.ever_submitted_teammate_count).to eq(1)
    expect(result.never_submitted_teammate_count).to eq(1)
  end

  it "ignores in-progress and empty submitted rows for usage" do
    create(:assignment_survey_response, company_teammate: active_teammate, assignment: held_assignment)
    create(
      :assignment_survey_response,
      company_teammate: active_teammate,
      assignment: held_assignment,
      submitted_at: 1.day.ago,
      understandable_rating: nil,
      possible_rating: nil,
      relevant_rating: nil,
      personal_alignment: nil
    )
    create_submitted!(understandable_rating: 4, personal_alignment: nil)

    expect(result.ever_submitted_teammate_count).to eq(1)
    expect(result.comment_stats.submitted_response_count).to eq(1)
  end

  it "reports per-field take rates for active teammates" do
    create_submitted!(
      understandable_rating: 5,
      possible_rating: nil,
      relevant_rating: nil,
      personal_alignment: "love"
    )
    create(
      :assignment_survey_response,
      company_teammate: other_active_teammate,
      assignment: held_assignment,
      understandable_rating: nil,
      possible_rating: 3,
      relevant_rating: nil,
      personal_alignment: nil,
      submitted_at: 2.days.ago
    )

    data = result.field_take_rates_chart_data
    expect(data[:categories]).to eq([ "Understandable", "Possible", "Relevant", "Personal alignment" ])
    expect(data[:series].first[:data]).to eq([ 1, 1, 0, 1 ])
  end

  it "reports personal alignment mix and comment rate" do
    create_submitted!(personal_alignment: "like", comment: "Clear outcomes")
    create(
      :assignment_survey_response,
      company_teammate: other_active_teammate,
      assignment: held_assignment,
      personal_alignment: "love",
      understandable_rating: 4,
      submitted_at: 3.days.ago,
      comment: nil
    )

    mix = result.personal_alignment_mix_chart_data
    like_index = mix[:categories].index("Like")
    love_index = mix[:categories].index("Love")
    expect(mix[:series].first[:data][like_index]).to eq(1)
    expect(mix[:series].first[:data][love_index]).to eq(1)
    expect(result.comment_stats.with_comment_count).to eq(1)
    expect(result.comment_stats.comment_rate).to eq(50.0)
  end

  it "splits survey-eligible vs neither and coverage" do
    create_submitted!

    eligibility = result.assignment_eligibility_chart_data
    expect(eligibility[:series].first[:data]).to eq([ 1, 1 ])

    coverage = result.assignment_coverage_chart_data
    expect(coverage[:series].first[:data]).to eq([ 1, 0 ])
  end

  it "classifies first submits vs re-submits by week" do
    create_submitted!(submitted_at: 3.weeks.ago.beginning_of_week + 1.day)
    create_submitted!(
      company_teammate: active_teammate,
      assignment: held_assignment,
      submitted_at: 1.week.ago.beginning_of_week + 1.day,
      understandable_rating: 6
    )

    series = result.submits_by_week_chart_data[:series]
    first = series.find { |row| row[:name] == "First submits" }
    resubmits = series.find { |row| row[:name] == "Re-submits" }
    expect(first[:data].sum).to eq(1)
    expect(resubmits[:data].sum).to eq(1)
  end
end
