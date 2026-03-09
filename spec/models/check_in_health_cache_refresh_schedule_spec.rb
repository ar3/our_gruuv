# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHealthCacheRefreshSchedule, type: :model do
  include ActiveSupport::Testing::TimeHelpers

  let(:teammate) { create(:teammate, organization: create(:organization, :company), first_employed_at: 1.month.ago) }

  describe 'associations' do
    it { is_expected.to belong_to(:teammate) }
  end

  describe '.schedule_refresh_for' do
    it 'creates a schedule with refresh_at 10 seconds from now' do
      travel_to Time.current do
        described_class.schedule_refresh_for(teammate.id)
        schedule = described_class.find_by(teammate_id: teammate.id)
        expect(schedule).to be_present
        expect(schedule.refresh_at).to be_within(2.seconds).of(10.seconds.from_now)
      end
    end

    it 'updates refresh_at when called again for same teammate' do
      travel_to Time.current do
        described_class.schedule_refresh_for(teammate.id)
        travel 5.seconds
        described_class.schedule_refresh_for(teammate.id)
        schedule = described_class.find_by(teammate_id: teammate.id)
        expect(schedule.refresh_at).to be_within(2.seconds).of(10.seconds.from_now) # from the second call
      end
    end
  end

  describe '.due_teammate_ids' do
    it 'returns teammate ids where refresh_at <= now' do
      schedule = described_class.create!(teammate: teammate, refresh_at: 1.hour.ago)
      expect(described_class.due_teammate_ids).to include(teammate.id)
    end

    it 'excludes future refresh_at' do
      described_class.create!(teammate: teammate, refresh_at: 1.hour.from_now)
      expect(described_class.due_teammate_ids).not_to include(teammate.id)
    end
  end

  describe '.remove_schedule_for' do
    it 'deletes schedules for given teammate ids' do
      described_class.create!(teammate: teammate, refresh_at: 1.hour.from_now)
      described_class.remove_schedule_for([teammate.id])
      expect(described_class.find_by(teammate_id: teammate.id)).to be_nil
    end
  end
end
