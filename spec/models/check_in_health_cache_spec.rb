# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHealthCache, type: :model do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }

  describe 'associations' do
    it { is_expected.to belong_to(:teammate) }
    it { is_expected.to belong_to(:organization) }
  end

  describe 'validations' do
    subject { create(:check_in_health_cache, teammate: teammate, organization: organization) }
    it { is_expected.to validate_presence_of(:payload) }
    it { is_expected.to validate_uniqueness_of(:teammate_id).scoped_to(:organization_id) }
  end

  describe 'payload accessors' do
    let(:cache) do
      create(:check_in_health_cache, teammate: teammate, organization: organization, payload: {
               'position' => { 'category' => 'green' },
               'assignments' => [{ 'item_id' => 1, 'category' => 'red' }],
               'aspirations' => [],
               'milestones' => { 'total_required' => 2, 'earned_count' => 1 }
             })
    end

    it 'returns position payload' do
      expect(cache.payload_position).to eq({ 'category' => 'green' })
    end

    it 'returns assignments payload' do
      expect(cache.payload_assignments).to eq([{ 'item_id' => 1, 'category' => 'red' }])
    end

    it 'returns aspirations payload' do
      expect(cache.payload_aspirations).to eq([])
    end

    it 'returns milestones payload' do
      expect(cache.payload_milestones).to eq({ 'total_required' => 2, 'earned_count' => 1 })
    end
  end

  describe '.category_to_points' do
    it 'returns 0 for red' do
      expect(described_class.category_to_points('red')).to eq(0)
    end
    it 'returns 1 for orange' do
      expect(described_class.category_to_points('orange')).to eq(1)
    end
    it 'returns 2 for light_blue and light_purple' do
      expect(described_class.category_to_points('light_blue')).to eq(2)
      expect(described_class.category_to_points('light_purple')).to eq(2)
    end
    it 'returns 3 for light_green' do
      expect(described_class.category_to_points('light_green')).to eq(3)
    end
    it 'returns 4 for green and neon_green' do
      expect(described_class.category_to_points('green')).to eq(4)
      expect(described_class.category_to_points('neon_green')).to eq(4)
    end
  end

  describe '#completion_points' do
    let(:cache) do
      create(:check_in_health_cache, teammate: teammate, organization: organization, payload: {
               'position' => { 'category' => 'green' },
               'assignments' => [{ 'category' => 'red' }, { 'category' => 'green' }],
               'aspirations' => [{ 'category' => 'orange' }],
               'milestones' => { 'total_required' => 4, 'earned_count' => 2 }
             })
    end

    it 'returns position points 4' do
      expect(cache.completion_points[:position]).to eq(4)
    end
    it 'returns assignments sum 0+4=4' do
      expect(cache.completion_points[:assignments]).to eq(4)
    end
    it 'returns aspirations sum 1' do
      expect(cache.completion_points[:aspirations]).to eq(1)
    end
    it 'returns milestones score (2/4*4)=2.0' do
      expect(cache.completion_points[:milestones]).to eq(2.0)
    end
  end
end
