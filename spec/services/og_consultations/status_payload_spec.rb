# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OgConsultations::StatusPayload do
  let(:organization) { create(:organization) }
  let(:ability) { create(:ability, company: organization) }
  let(:consultation) do
    create_ability_clarity_consultation!(
      ability: ability,
      status: 'processing',
      units_total: 1,
      units_completed: 0
    ).tap { |c| c.update!(started_at: 45.seconds.ago) }
  end

  it 'includes elapsed, units, and ETA fields for consultations' do
    allow(OgConsultations::EtaEstimator).to receive(:call).and_return(
      OgConsultations::EtaEstimator::Result.new(
        estimated_duration_seconds: 90,
        eta_confidence: 'medium',
        units_total: 1,
        units_completed: 0,
        sample_size: 5
      )
    )

    payload = described_class.for_consultation(consultation, clarity_rating: 'green')

    expect(payload[:status]).to eq('processing')
    expect(payload[:elapsed_seconds]).to be >= 45
    expect(payload[:slow]).to eq(false)
    expect(payload[:units_total]).to eq(1)
    expect(payload[:units_completed]).to eq(0)
    expect(payload[:estimated_duration_seconds]).to eq(90)
    expect(payload[:eta_confidence]).to eq('medium')
    expect(payload[:clarity_rating]).to eq('green')
  end

  it 'marks slow after the shared threshold' do
    consultation.update!(started_at: 100.seconds.ago)
    allow(OgConsultations::EtaEstimator).to receive(:call).and_return(
      OgConsultations::EtaEstimator::Result.new(
        estimated_duration_seconds: nil,
        eta_confidence: 'low',
        units_total: 1,
        units_completed: 0,
        sample_size: 0
      )
    )

    payload = described_class.for_consultation(consultation)

    expect(payload[:slow]).to eq(true)
  end

  it 'builds heartbeat payloads without ETA' do
    transcript = create(:possible_observation_transcript, organization: organization, extraction_status: 'pending')

    payload = described_class.for_heartbeat(record: transcript, status: 'pending')

    expect(payload[:estimated_duration_seconds]).to be_nil
    expect(payload[:eta_confidence]).to be_nil
    expect(payload[:units_total]).to be_nil
  end
end
