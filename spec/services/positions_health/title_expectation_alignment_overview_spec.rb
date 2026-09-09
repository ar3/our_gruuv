# frozen_string_literal: true

require "rails_helper"

RSpec.describe PositionsHealth::TitleExpectationAlignmentOverview do
  let(:organization) { create(:organization) }
  let(:major_level) { create(:position_major_level) }
  let(:department) { create(:department, company: organization, name: "Engineering") }

  it "groups titles by department and orders scored best to worst with unscored last" do
    strong = create(:title, company: organization, department: department, position_major_level: major_level, external_title: "Staff")
    weak = create(:title, company: organization, department: department, position_major_level: major_level, external_title: "Junior")
    missing = create(:title, company: organization, department: department, position_major_level: major_level, external_title: "Intern")
    company_wide = create(:title, company: organization, department: nil, position_major_level: major_level, external_title: "CEO", end_cap: true)

    TitleExpectationAlignmentScore.create!(
      title: strong,
      organization: organization,
      score: 90,
      cells: [],
      path_clarity: true,
      calculated_at: Time.current
    )
    TitleExpectationAlignmentScore.create!(
      title: weak,
      organization: organization,
      score: 20,
      cells: [],
      path_clarity: false,
      calculated_at: Time.current
    )
    Titles::ExpectationAlignmentScore.recalculate!(title: company_wide, refresh_positions: false)

    result = described_class.call(organization: organization)

    expect(result.total_count).to eq(4)
    expect(result.missing_count).to eq(1)
    expect(result.department_groups.first.label).to eq("Company-wide")
    eng = result.department_groups.find { |g| g.label == "Engineering" }
    expect(eng.titles.map { |r| r.title.external_title }).to eq(%w[Staff Junior Intern])
    expect(eng.titles.last.missing?).to be(true)
    expect(eng.titles.first.band_key).to eq(:aligned)
    expect(eng.titles.first.score).to eq(90.0)
    expect(result.band_counts[:aligned]).to eq(1)
    expect(result.band_counts[:unscored]).to eq(1)
    expect(result.band_counts.values.sum).to eq(4)
  end
end
