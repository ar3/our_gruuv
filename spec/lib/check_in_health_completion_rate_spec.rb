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

    it 'returns 100 when earned points match max (4 position + 4 per assignment row + 4 per aspiration row)' do
      # Max denominator: see CheckInHealthCache — each payload row scores 0–4; here 1×4 + 2×4 + 1×4 = 16.
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

    it 'returns 50 when total earned points are half of max' do
      # Earned 2+4+2 = 8; max 4 + (2 assignment slots × 4) + (1 aspiration × 4) = 16 → 50%.
      cache = instance_double(
        CheckInHealthCache,
        completion_points: {
          position: 2.0,
          assignments: 4.0,
          aspirations: 2.0
        },
        payload_assignments: [{}, {}],
        payload_aspirations: [{}]
      )
      expect(described_class.completion_rate_for_caches([cache])).to eq(50.0)
    end
  end

  describe '.contribution_tuple_for_cache' do
    it 'returns earned and max points' do
      cache = instance_double(
        CheckInHealthCache,
        completion_points: { position: 4.0, assignments: 4.0, aspirations: 4.0 },
        payload_assignments: [{}],
        payload_aspirations: [{}]
      )
      pts, mx = described_class.contribution_tuple_for_cache(cache)
      expect(pts).to eq(12.0)
      expect(mx).to eq(12.0)
    end
  end

  describe '.average_completion_rate_per_teammate' do
    it 'returns 0 when no teammate ids' do
      expect(described_class.average_completion_rate_per_teammate([], 1)).to eq(0.0)
    end
  end

  describe '.teammate_fully_clear_on_check_ins?' do
    it 'is false when cache is nil' do
      expect(described_class.teammate_fully_clear_on_check_ins?(nil)).to be(false)
    end
  end
end
