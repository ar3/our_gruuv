# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AbilitiesHrReview::EnrichPreview do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:event) do
    create(
      :upload_abilities_hr_review,
      organization: organization,
      creator: person,
      initiator: person,
      preview_actions: {
        'ability_groups' => [
          {
            'id' => 'g1',
            'state' => 'pending',
            'enrichment_status' => 'pending',
            'ability_name' => 'Knife work',
            'match_kind' => 'none',
            'description' => { 'raw' => 'Body', 'normalized' => 'Body' },
            'milestones' => { '1' => { 'raw' => 'M1', 'normalized' => 'M1' } }
          }
        ]
      }
    )
  end

  it 'skips enrichment for exact_insensitive name matches' do
    event.update!(
      preview_actions: event.preview_actions.merge(
        'ability_groups' => [
          {
            'id' => 'g1',
            'state' => 'pending',
            'enrichment_status' => 'pending',
            'ability_match_kind' => 'exact_insensitive',
            'ability_name' => 'Knife work',
            'match_candidates' => [{ 'ability_id' => 1, 'confidence' => 100, 'name' => 'Knife work' }]
          }
        ]
      )
    )

    expect(Llm::AbilitiesHrReviewEnricher).not_to receive(:enrich_group)
    described_class.call(bulk_sync_event: event)
    expect(event.reload.preview_actions['ability_groups'].first['enrichment_status']).to eq('complete')
  end

  it 'marks groups enriched synchronously' do
    allow(Llm::AbilitiesHrReviewEnricher).to receive(:enrich_group).and_wrap_original do |method, group, **kwargs|
      method.call(group, **kwargs).merge('match_candidates' => [])
    end

    expect(described_class.call(bulk_sync_event: event)).to be true

    group = event.reload.preview_actions['ability_groups'].first
    expect(group['enrichment_status']).to eq('complete')
    expect(event.preview_actions.dig('enrichment', 'status')).to eq('complete')
  end
end
