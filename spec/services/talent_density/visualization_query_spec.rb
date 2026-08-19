# frozen_string_literal: true

require "rails_helper"

RSpec.describe TalentDensity::VisualizationQuery do
  let(:company) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, :assigned_employee, organization: company) }
  let(:ic) { create(:company_teammate, :assigned_employee, organization: company) }

  before do
    create(:employment_tenure, company_teammate: ic, company: company, manager_teammate: manager)
  end

  it "places a teammate with stance and finalized rating, and leaves others unplaced" do
    tenure = ic.employment_tenures.find_by!(ended_at: nil)
    create(:talent_density_stance, company_teammate: ic, company: company, stance: :fine_either_way)
    create(:position_check_in, :closed, teammate: ic, employment_tenure: tenure, official_rating: 2)

    query = described_class.new(teammates: [ic, manager])
    expect(query.cell("fine_either_way", 2).map { |point| point.teammate.id }).to eq([ic.id])
    expect(query.unplaced.map { |point| point.teammate.id }).to include(manager.id)
  end
end
