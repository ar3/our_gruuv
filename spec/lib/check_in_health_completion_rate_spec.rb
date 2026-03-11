# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHealthCompletionRate do
  describe '.BAR_CATEGORIES' do
    it 'includes expected category keys' do
      expect(described_class::BAR_CATEGORIES).to eq(
        %w[red orange light_blue light_purple light_green green neon_green]
      )
    end
  end

  describe '.aggregate_category_counts' do
    it 'returns zeros for empty items' do
      result = described_class.aggregate_category_counts([])
      described_class::BAR_CATEGORIES.each do |c|
        expect(result[c]).to eq(0)
      end
    end

    it 'counts by category' do
      items = [
        { 'category' => 'green' },
        { 'category' => 'red' },
        { 'category' => 'green' }
      ]
      result = described_class.aggregate_category_counts(items)
      expect(result['green']).to eq(2)
      expect(result['red']).to eq(1)
      expect(result['neon_green']).to eq(0)
    end
  end

  describe '.aggregate_position_counts' do
    it 'returns zeros for empty positions' do
      result = described_class.aggregate_position_counts([])
      described_class::BAR_CATEGORIES.each do |c|
        expect(result[c]).to eq(0)
      end
    end

    it 'counts by position category, defaulting nil/blank to red' do
      positions = [
        { 'category' => 'green' },
        {}
      ]
      result = described_class.aggregate_position_counts(positions)
      expect(result['green']).to eq(1)
      expect(result['red']).to eq(1)
    end
  end

  describe '.completion_rate_for_caches' do
    it 'returns 0 for empty caches' do
      expect(described_class.completion_rate_for_caches([])).to eq(0)
    end

    it 'returns 100 when all points are max (4 per area)' do
      cache = instance_double(
        CheckInHealthCache,
        completion_points: {
          position: 4.0,
          assignments: 8.0,
          aspirations: 4.0
        },
        payload_assignments: [{}, {}],
        payload_aspirations: [{}]
      )
      expect(described_class.completion_rate_for_caches([cache])).to eq(100.0)
    end

    it 'returns ~50 when half the points are earned' do
      cache = instance_double(
        CheckInHealthCache,
        completion_points: {
          position: 2.0,
          assignments: 4.0,
          aspirations: 2.0
        },
        payload_assignments: [{}],
        payload_aspirations: [{}]
      )
      rate = described_class.completion_rate_for_caches([cache])
      expect(rate).to be_within(1).of(50)
    end
  end
end
