# frozen_string_literal: true

require "rails_helper"

RSpec.describe TalentDensityStance, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, :assigned_employee, organization: organization) }

  it "is unique per teammate and records PaperTrail versions" do
    PaperTrail.enabled = true
    stance = create(:talent_density_stance, company_teammate: teammate, company: organization, notes: "v1")
    stance.update!(notes: "v2")

    expect(described_class.where(company_teammate: teammate).count).to eq(1)
    expect(stance.versions.size).to be >= 2
  ensure
    PaperTrail.enabled = true
  end

  it "allows a nil stance (not yet rated)" do
    stance = described_class.create!(company_teammate: teammate, company: organization, stance: nil, notes: "")
    expect(stance.stance).to be_nil
  end
end
