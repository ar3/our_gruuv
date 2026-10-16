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

  def typed_name
    manager_teammate.person.all_names_display_name
  end

  it 'creates milestones 1..official and marks the item awarded when cosign is skipped' do
    result = described_class.call(
      item: item,
      official_level: 2,
      certifying_teammate: manager_teammate,
      created_by_person: manager_teammate.person,
      organization: organization,
      certification_note: 'Calibration note',
      awarder_typed_name: typed_name,
      skip_cosign: true
    )

    expect(result.ok?).to eq(true)
    expect(item.reload.official_milestone_level).to eq(2)
    expect(employee_teammate.teammate_milestones.where(ability: ability).pluck(:milestone_level)).to contain_exactly(1, 2)
    expect(employee_teammate.teammate_milestones.where(ability: ability).pluck(:certification_note).uniq)
      .to eq(['Calibration note'])
  end

  it 'falls back to the default certification note when blank' do
    result = described_class.call(
      item: item,
      official_level: 1,
      certifying_teammate: manager_teammate,
      created_by_person: manager_teammate.person,
      organization: organization,
      certification_note: '   ',
      awarder_typed_name: typed_name,
      skip_cosign: true
    )

    expect(result.ok?).to eq(true)
    expect(employee_teammate.teammate_milestones.find_by!(ability: ability, milestone_level: 1).certification_note)
      .to eq(described_class::CERTIFICATION_NOTE)
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

  it 'holds milestones when co-sign is requested' do
    cosigner = create(:teammate, organization: organization)
    result = described_class.call(
      item: item,
      official_level: 2,
      certifying_teammate: manager_teammate,
      created_by_person: manager_teammate.person,
      organization: organization,
      awarder_typed_name: typed_name,
      skip_cosign: false,
      cosign_invitee_ids: [cosigner.id]
    )

    expect(result.ok?).to eq(true)
    expect(item.reload.awarded?).to eq(true)
    expect(employee_teammate.teammate_milestones.where(ability: ability)).to be_empty
    award = MilestoneAward.find_by!(ability_milestone_calibration_item: item)
    expect(award.pending_cosign?).to eq(true)
  end
end
