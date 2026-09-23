# frozen_string_literal: true

require "rails_helper"

RSpec.describe TalentDensityStance, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, :assigned_employee, organization: organization) }

  it "is unique per teammate and period and records PaperTrail versions" do
    PaperTrail.enabled = true
    stance = create(:talent_density_stance, company_teammate: teammate, company: organization, notes: "v1")
    stance.update!(notes: "v2")

    expect(described_class.where(company_teammate: teammate).count).to eq(1)
    expect(stance.versions.size).to be >= 2

    other_month = described_class.current_period_month - 1.month
    create(
      :talent_density_stance,
      company_teammate: teammate,
      company: organization,
      period_month: other_month,
      notes: "prior"
    )
    expect(described_class.where(company_teammate: teammate).count).to eq(2)
  ensure
    PaperTrail.enabled = true
  end

  it "allows a nil stance (not yet rated)" do
    stance = described_class.create!(
      company_teammate: teammate,
      company: organization,
      period_month: described_class.current_period_month,
      stance: nil,
      notes: ""
    )
    expect(stance.stance).to be_nil
  end

  it "treats past months as locked and immutable" do
    stance = create(
      :talent_density_stance,
      company_teammate: teammate,
      company: organization,
      period_month: described_class.current_period_month - 1.month
    )
    expect(stance).to be_locked
    expect(stance.update(stance: :take_the_swap)).to eq(false)
    expect(stance.errors[:base]).to include(/locked/)
  end

  describe ".prior_by_teammate_id" do
    it "returns the latest reflection before the given period" do
      older = create(
        :talent_density_stance,
        company_teammate: teammate,
        company: organization,
        period_month: Date.new(2026, 1, 1),
        stance: :take_the_swap
      )
      create(
        :talent_density_stance,
        company_teammate: teammate,
        company: organization,
        period_month: Date.new(2026, 3, 1),
        stance: :try_to_avoid_the_swap
      )

      prior = described_class.prior_by_teammate_id(
        [teammate.id],
        before_period: Date.new(2026, 9, 1)
      )
      expect(prior[teammate.id].period_month).to eq(Date.new(2026, 3, 1))
      expect(prior[teammate.id].id).not_to eq(older.id)
    end
  end
end
