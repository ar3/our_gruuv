# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHealthCacheBuilder do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }

  describe '.call' do
    it 'returns a hash with position, assignments, aspirations, milestones' do
      result = described_class.call(teammate, organization)
      expect(result).to have_key('position')
      expect(result).to have_key('assignments')
      expect(result).to have_key('aspirations')
      expect(result).to have_key('milestones')
    end

    it 'position has category and date keys' do
      result = described_class.call(teammate, organization)
      expect(result['position']).to include('category', 'employee_completed_at', 'manager_completed_at', 'official_check_in_completed_at', 'acknowledged_at')
      expect(result['position']['category']).to be_in(%w[red orange light_blue light_purple light_green green neon_green])
    end

    it 'assignments is an array' do
      result = described_class.call(teammate, organization)
      expect(result['assignments']).to be_an(Array)
    end

    it 'aspirations is an array' do
      result = described_class.call(teammate, organization)
      expect(result['aspirations']).to be_an(Array)
    end

    it 'milestones has total_required and earned_count' do
      result = described_class.call(teammate, organization)
      expect(result['milestones']).to include('total_required', 'earned_count')
      expect(result['milestones']['total_required']).to be_a(Integer)
      expect(result['milestones']['earned_count']).to be_a(Integer)
    end
  end

  describe '#build_and_save' do
    it 'creates or updates CheckInHealthCache for the teammate' do
      expect { described_class.new(teammate, organization).build_and_save }.to change(CheckInHealthCache, :count).by(1)
      cache = CheckInHealthCache.find_by(teammate: teammate, organization: organization)
      expect(cache.payload).to have_key('position')
      expect(cache.refreshed_at).to be_present
    end

    it 'idempotent: second call updates same record' do
      described_class.new(teammate, organization).build_and_save
      expect { described_class.new(teammate, organization).build_and_save }.not_to change(CheckInHealthCache, :count)
    end
  end
end
