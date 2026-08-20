# frozen_string_literal: true

require "rails_helper"

RSpec.describe TalentDensity::GuidanceMatrixQuery do
  let(:company) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:ic) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:assignment) { create(:assignment, company: company, title: "Core Work") }

  before do
    create(:employment_tenure, company_teammate: ic, company: company, manager_teammate: manager)
  end

  it "places a teammate with finalized overall and computable guidance" do
    tenure = ic.employment_tenures.find_by!(ended_at: nil)
    create(
      :assignment_tenure,
      teammate: ic,
      assignment: assignment,
      anticipated_energy_percentage: 100,
      ended_at: nil,
      official_rating: "meeting"
    )
    create(
      :assignment_check_in,
      :officially_completed,
      teammate: ic,
      assignment: assignment,
      official_rating: "meeting"
    )
    create(:position_check_in, :closed, teammate: ic, employment_tenure: tenure, official_rating: 3)

    query = described_class.new(teammates: [ic])
    expect(query.cell(2, 3).map { |point| point.teammate.id }).to eq([ic.id])
    expect(query.unplaced).to be_empty
  end

  it "lists teammates without guidance or finalized overall as unplaced" do
    query = described_class.new(teammates: [ic])
    expect(query.placed).to be_empty
    expect(query.unplaced.map { |point| point.teammate.id }).to eq([ic.id])
  end
end
