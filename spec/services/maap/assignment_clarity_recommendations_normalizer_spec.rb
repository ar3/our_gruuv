# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Maap::AssignmentClarityRecommendationsNormalizer do
  describe '.call' do
    it 'keeps high-confidence items with required fields' do
      raw = [
        {
          'id' => 'r1',
          'confidence' => 'high',
          'kind' => 'edit_tagline',
          'title' => 'Sharpen tagline',
          'rationale' => 'Clear scope.',
          'payload' => { 'x' => 1 }
        }
      ]
      out = described_class.call(raw)
      expect(out.size).to eq(1)
      expect(out.first['id']).to eq('r1')
      expect(out.first['payload']).to eq({ 'x' => 1 })
    end

    it 'drops non-high confidence' do
      raw = [{ 'id' => 'a', 'confidence' => 'medium', 'kind' => 'k', 'title' => 't', 'rationale' => 'r' }]
      expect(described_class.call(raw)).to eq([])
    end

    it 'parses JSON string' do
      json = '[{"id":"z","confidence":"high","kind":"k","title":"t","rationale":"why"}]'
      out = described_class.call(json)
      expect(out.first['id']).to eq('z')
    end

    it 'caps at MAX_ITEMS' do
      raw = (1..15).map do |i|
        { 'id' => "i#{i}", 'confidence' => 'high', 'kind' => 'k', 'title' => 't', 'rationale' => 'r' }
      end
      expect(described_class.call(raw).size).to eq(described_class::MAX_ITEMS)
    end
  end
end
