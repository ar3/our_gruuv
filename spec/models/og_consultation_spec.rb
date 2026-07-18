# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OgConsultation, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:person) }
  let(:ability) { create(:ability, company: organization, created_by: creator, updated_by: creator) }

  it 'loads latest consultation for a subject and kind' do
    older = create_ability_clarity_consultation!(ability: ability, status: 'completed', completed_at: 2.days.ago)
    newer = create_ability_clarity_consultation!(ability: ability, status: 'completed', completed_at: 1.day.ago)

    expect(ability.latest_ability_clarity_consultation).to eq(newer)
    expect(described_class.latest_for(subject: ability, kind: OgConsultation::KIND_ABILITY_CLARITY)).to eq(newer)
    expect(older.id).not_to eq(newer.id)
  end

  it 'delegates output fields to the result' do
    consultation = create_ability_clarity_consultation!(
      ability: ability,
      status: 'completed',
      output_text: 'Done',
      clarity_rating: 'green'
    )
    expect(consultation.output_text).to eq('Done')
    expect(consultation.clarity_rating).to eq('green')
  end
end
