# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::AbilityResolver do
  let(:organization) { create(:organization) }

  it 'returns exact match' do
    a = create(:ability, company: organization, name: 'Knife work')
    res = described_class.call(organization: organization, name: 'Knife work')
    expect(res['ability_id']).to eq(a.id)
    expect(res['match_kind']).to eq('exact')
    expect(res['canonical_name']).to eq('Knife work')
  end

  it 'returns flexible match for & / and variant' do
    a = create(:ability, company: organization, name: 'R & D')
    res = described_class.call(organization: organization, name: 'R and D')
    expect(res['ability_id']).to eq(a.id)
    expect(res['match_kind']).to eq('flexible')
  end

  it 'returns none when no ability matches' do
    create(:ability, company: organization, name: 'Unrelated')
    res = described_class.call(organization: organization, name: 'XyzAbcNoSuchAbilityInDatabase999')
    expect(res['ability_id']).to be_nil
    expect(res['match_kind']).to eq('none')
  end
end
