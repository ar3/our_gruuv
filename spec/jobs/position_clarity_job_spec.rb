# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PositionClarityJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let!(:position) { create(:position, title: title, position_level: position_level) }
  let!(:consultation) { create_position_clarity_consultation!(position: position) }

  it 'invokes the runner' do
    expect(Maap::PositionClarityRunner).to receive(:call).with(
      position: position,
      og_consultation: consultation
    ).and_return(true)

    described_class.perform_now(position.id, consultation.id)
  end
end
