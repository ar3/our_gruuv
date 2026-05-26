# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Llm::AbilitiesHrReviewMatcher do
  let(:organization) { create(:organization) }
  let!(:existing) do
    create(
      :ability,
      company: organization,
      name: 'Knife skills',
      description: 'Use knives safely in prep.',
      milestone_1_description: 'Basic grip'
    )
  end

  let(:group) do
    {
      'ability_name' => 'Knife work',
      'match_kind' => 'none',
      'match_candidates' => [],
      'description' => { 'raw' => 'Knife safety', 'normalized' => 'Knife safety', 'proposed' => 'Knife safety' },
      'milestones' => {
        '1' => { 'raw' => 'Grip basics', 'normalized' => 'Grip basics', 'proposed' => 'Grip basics' }
      }
    }
  end

  before do
    allow_any_instance_of(described_class).to receive(:bedrock_configured?).and_return(true)
    allow(RubyLLM).to receive(:chat).and_return(chat_double)
  end

  let(:chat_double) do
    double('Chat', with_instructions: nil).tap do |chat|
      allow(chat).to receive(:with_instructions) { chat }
      allow(chat).to receive(:ask).and_return(
        double(
          content: {
            matches: [{ ability_id: existing.id, confidence: 88 }]
          }.to_json
        )
      )
    end
  end

  it 'lists AI candidates but does not default below 90% confidence' do
    result = described_class.apply_to_group(group, organization: organization)
    expect(result['match_candidates'].size).to eq(1)
    expect(result['match_candidates'].first['confidence']).to eq(88)
    expect(result['matched_ability_id']).to be_nil
    expect(result['ability_match_kind']).to eq('ai')
  end

  it 'defaults the ability at 90% confidence or higher' do
    allow(chat_double).to receive(:ask).and_return(
      double(content: { matches: [{ ability_id: existing.id, confidence: 92 }] }.to_json)
    )
    result = described_class.apply_to_group(group, organization: organization)
    expect(result['matched_ability_id']).to eq(existing.id)
  end

  it 'skips when already exact_insensitive' do
    exact_group = group.merge(
      'ability_match_kind' => 'exact_insensitive',
      'match_candidates' => [{ 'ability_id' => 1, 'confidence' => 100 }]
    )
    result = described_class.apply_to_group(exact_group, organization: organization)
    expect(RubyLLM).not_to have_received(:chat)
    expect(result['ability_match_kind']).to eq('exact_insensitive')
  end
end
