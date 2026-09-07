# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilityMilestoneCalibrationAwardService do
  let(:organization) { create(:organization) }
  let(:manager_teammate) { create(:teammate, organization: organization) }
  let(:employee_teammate) { create(:teammate, organization: organization) }
  let(:ability) { create(:ability, company: organization) }
  let(:calibration) do
    create(:ability_milestone_calibration, company_teammate: employee_teammate)
  end
  let(:item) do
    create(:ability_milestone_calibration_item, ability_milestone_calibration: calibration, ability: ability,
                                                employee_rating: 2, manager_rating: 3)
  end

  it 'creates milestones 1..official and marks the item awarded' do
    result = described_class.call(
      item: item,
      official_level: 2,
      certifying_teammate: manager_teammate,
      created_by_person: manager_teammate.person,
      organization: organization
    )

    expect(result.ok?).to eq(true)
    expect(item.reload.official_milestone_level).to eq(2)
    expect(employee_teammate.teammate_milestones.where(ability: ability).pluck(:milestone_level)).to contain_exactly(1, 2)
  end

  it 'records official 0 without creating teammate milestones' do
    result = described_class.call(
      item: item,
      official_level: 0,
      certifying_teammate: manager_teammate,
      created_by_person: manager_teammate.person,
      organization: organization
    )

    expect(result.ok?).to eq(true)
    expect(item.reload.official_milestone_level).to eq(0)
    expect(employee_teammate.teammate_milestones.where(ability: ability)).to be_empty
  end
end
