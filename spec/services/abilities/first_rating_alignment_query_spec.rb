# frozen_string_literal: true

require "rails_helper"

RSpec.describe Abilities::FirstRatingAlignmentQuery do
  let(:organization) { create(:organization) }
  let(:ability) { create(:ability, company: organization) }

  def item_for(teammate, emp:, mgr:, official: nil, awarded: false)
    calibration = create(:ability_milestone_calibration, company_teammate: teammate)
    create(
      :ability_milestone_calibration_item,
      ability_milestone_calibration: calibration,
      ability: ability,
      employee_first_rating: emp,
      manager_first_rating: mgr,
      official_milestone_level: official,
      awarded_at: awarded ? Time.current : nil
    )
  end

  it "classifies both-rated pairs without final into no-final columns with no arrow" do
    t1 = create(:teammate, :unassigned_employee, organization: organization)
    t2 = create(:teammate, :unassigned_employee, organization: organization)
    item_for(t1, emp: 2, mgr: 2)
    item_for(t2, emp: 3, mgr: 1)

    query = described_class.call(ability: ability)

    expect(query.cell(:emp_mgr_same_no_final).size).to eq(1)
    expect(query.cell(:emp_mgr_differed_no_final).size).to eq(1)
    expect(query.cell(:emp_mgr_same_no_final).first.arrow).to be_nil
    expect(query.cell(:emp_mgr_differed_no_final).first.arrow).to be_nil
  end

  it "classifies awarded finals into three-way patterns and sets arrows" do
    t1 = create(:teammate, :unassigned_employee, organization: organization)
    t2 = create(:teammate, :unassigned_employee, organization: organization)
    item_for(t1, emp: 2, mgr: 2, official: 2, awarded: true)
    item_for(t2, emp: 2, mgr: 2, official: 4, awarded: true)

    query = described_class.call(ability: ability)

    expect(query.cell(:all_same).size).to eq(1)
    expect(query.cell(:all_same).first.arrow).to be_nil
    expect(query.cell(:emp_mgr_same_final_differed).size).to eq(1)
    expect(query.cell(:emp_mgr_same_final_differed).first.arrow).to eq(:better)
  end

  it "ignores items missing a first rating on either side" do
    teammate = create(:teammate, :unassigned_employee, organization: organization)
    calibration = create(:ability_milestone_calibration, company_teammate: teammate)
    create(
      :ability_milestone_calibration_item,
      ability_milestone_calibration: calibration,
      ability: ability,
      employee_first_rating: 2,
      manager_first_rating: nil
    )

    expect(described_class.call(ability: ability)).to be_empty
  end
end
