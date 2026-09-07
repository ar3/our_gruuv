# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilityMilestoneCalibrationAbilitiesCatalog do
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Tenure Assign') }
  let(:ability) { create(:ability, company: organization, name: 'TenureAbility') }
  let(:other_ability) { create(:ability, company: organization, name: 'OtherTenureAbility') }

  before do
    create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
    create(:assignment_ability, assignment: assignment, ability: other_ability, milestone_level: 1)
    create(:assignment_tenure, teammate: teammate, assignment: assignment)
  end

  it 'includes abilities from assignment tenures' do
    rows = described_class.call(teammate: teammate, organization: organization)
    ids = rows.map { |r| r[:ability_id] }

    expect(ids).to include(ability.id, other_ability.id)
  end

  it 'counts will_show vs full_set for entry copy' do
    certifier = create(:teammate, organization: organization)
    create(:teammate_milestone, company_teammate: teammate, ability: ability, milestone_level: 1,
                                certifying_teammate: certifier)

    counts = described_class.entry_counts(teammate: teammate, organization: organization)
    expect(counts[:full_set]).to eq(2)
    expect(counts[:will_show]).to eq(1)
  end

  it 'only collects abilities from required (not suggested) position assignments' do
    position_major_level = create(:position_major_level, major_level: 1, set_name: 'Engineering')
    title = create(:title, company: organization, position_major_level: position_major_level)
    position_level = create(:position_level, position_major_level: position_major_level, level: '1.1')
    position = create(:position, title: title, position_level: position_level)

    suggested_assignment = create(:assignment, company: organization, title: 'Suggested Only')
    suggested_ability = create(:ability, company: organization, name: 'SuggestedOnlyAbility')
    required_on_position = create(:assignment, company: organization, title: 'Required On Position')
    required_on_position_ability = create(:ability, company: organization, name: 'RequiredOnPositionAbility')
    create(:position_assignment, position: position, assignment: suggested_assignment, assignment_type: 'suggested')
    create(:position_assignment, position: position, assignment: required_on_position, assignment_type: 'required')
    create(:assignment_ability, assignment: suggested_assignment, ability: suggested_ability, milestone_level: 1)
    create(:assignment_ability, assignment: required_on_position, ability: required_on_position_ability, milestone_level: 2)

    ids = Set.new
    described_class.new(teammate: teammate, organization: organization)
      .send(:add_position_ability_sources, position, ids)

    expect(ids).to include(required_on_position_ability.id)
    expect(ids).not_to include(suggested_ability.id)
  end
end
