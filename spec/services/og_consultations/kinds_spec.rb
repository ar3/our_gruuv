# frozen_string_literal: true

require 'rails_helper'

RSpec.describe OgConsultations::Kinds do
  it 'registers every OgConsultation::KINDS entry' do
    expect(described_class.kinds).to match_array(OgConsultation::KINDS)
  end

  it 'resolves ability clarity classes used by the reference path' do
    entry = described_class.fetch(OgConsultation::KIND_ABILITY_CLARITY)

    expect(entry.result_class).to eq(AbilityClarityResult)
    expect(entry.job_class).to eq(AbilityClarityJob)
    expect(entry.runner_class).to eq(Maap::AbilityClarityRunner)
    expect(entry.llm_purpose).to eq('ability_clarity')
    expect(entry.billable).to be(true)
  end

  it 'keeps historical OGO search transcript kind without a job' do
    entry = described_class.fetch(OgConsultation::KIND_OGO_SEARCH_TRANSCRIPT)

    expect(entry.result_class).to eq(OgoSearchResult)
    expect(entry.job_class).to be_nil
    expect(entry.runner_class).to be_nil
  end

  it 'raises a clear error for unknown kinds' do
    expect { described_class.fetch('not_a_kind') }.to raise_error(KeyError, /Unknown OgConsultation kind/)
  end
end
