# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OgConsultations::EtaEstimator do
  let(:organization) { create(:organization) }
  let(:ability) { create(:ability, company: organization) }
  let(:consultation) do
    create_ability_clarity_consultation!(
      ability: ability,
      status: 'processing',
      model_id: 'test-model',
      prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
      units_total: 1,
      units_completed: 0
    ).tap { |c| c.update!(started_at: 30.seconds.ago) }
  end

  def create_invocation!(duration_ms:, finished_at: Time.current)
    LlmInvocation.create!(
      purpose: 'ability_clarity',
      model_id: 'test-model',
      prompt_version: Maap::Prompts::MAAP_PROMPTS_VERSION,
      status: 'completed',
      organization_id: organization.id,
      duration_ms: duration_ms,
      started_at: finished_at - (duration_ms / 1000.0).seconds,
      finished_at: finished_at,
      cost_micros: 0
    )
  end

  it 'returns low confidence and nil estimate when sample size is below threshold' do
    create_invocation!(duration_ms: 10_000)
    create_invocation!(duration_ms: 12_000)

    result = described_class.call(consultation)

    expect(result.eta_confidence).to eq('low')
    expect(result.estimated_duration_seconds).to be_nil
    expect(result.sample_size).to eq(2)
  end

  it 'estimates total duration from median invocation duration' do
    [8_000, 10_000, 12_000].each_with_index do |ms, i|
      create_invocation!(duration_ms: ms, finished_at: (i + 1).minutes.ago)
    end

    result = described_class.call(consultation)

    expect(result.eta_confidence).to eq('medium')
    expect(result.estimated_duration_seconds).to eq(10)
    expect(result.units_total).to eq(1)
    expect(result.units_completed).to eq(0)
  end

  it 'scales total estimate by units_total for multi-unit consultations' do
    consultation.update!(units_total: 4, units_completed: 1)
    [5_000, 5_000, 5_000].each_with_index do |ms, i|
      create_invocation!(duration_ms: ms, finished_at: (i + 1).minutes.ago)
    end

    result = described_class.call(consultation)

    expect(result.estimated_duration_seconds).to eq(20)
  end

  it 'falls back to completed consultation wall times when invocations are sparse' do
    3.times do |i|
      create_ability_clarity_consultation!(
        ability: ability,
        status: 'completed',
        model_id: 'other-model',
        prompt_version: 'other',
        completed_at: (i + 1).hours.ago
      ).tap do |c|
        c.update!(started_at: c.completed_at - 20.seconds)
      end
    end

    result = described_class.call(consultation)

    expect(result.eta_confidence).to eq('medium')
    expect(result.estimated_duration_seconds).to eq(20)
  end
end
