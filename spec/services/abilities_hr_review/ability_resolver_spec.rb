# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::AbilityResolver do
  let(:organization) { create(:organization) }

  it 'returns case-insensitive trimmed exact match with 100% confidence' do
    a = create(:ability, company: organization, name: 'Knife work')
    res = described_class.call(organization: organization, name: '  KNIFE WORK  ')
    expect(res['ability_id']).to eq(a.id)
    expect(res['match_kind']).to eq('exact_insensitive')
    expect(res['match_candidates'].size).to eq(1)
    expect(res['match_candidates'].first['confidence']).to eq(100)
    expect(res['match_candidates'].first['name']).to eq('Knife work')
  end

  it 'returns none when no case-insensitive name match' do
    create(:ability, company: organization, name: 'Unrelated')
    res = described_class.call(organization: organization, name: 'XyzAbcNoSuchAbilityInDatabase999')
    expect(res['ability_id']).to be_nil
    expect(res['match_kind']).to eq('none')
    expect(res['match_candidates']).to eq([])
  end

  it 'does not fuzzy-match similar names without exact_insensitive hit' do
    create(:ability, company: organization, name: 'R & D')
    res = described_class.call(organization: organization, name: 'R and D')
    expect(res['ability_id']).to be_nil
    expect(res['match_kind']).to eq('none')
  end
end
