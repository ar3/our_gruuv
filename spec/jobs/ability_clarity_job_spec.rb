# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilityClarityJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:person) }
  let!(:ability) { create(:ability, company: organization, created_by: creator, updated_by: creator) }
  let!(:consultation) { create_ability_clarity_consultation!(ability: ability) }

  it 'invokes the runner' do
    expect(Maap::AbilityClarityRunner).to receive(:call).with(
      ability: ability,
      og_consultation: consultation
    ).and_return(true)

    described_class.perform_now(ability.id, consultation.id)
    expect(consultation.reload.status).to eq('processing')
  end
end
