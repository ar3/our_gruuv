# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHealthCacheProcessSchedulesJob, type: :job do
  let(:teammate) { create(:teammate, organization: create(:organization, :company), first_employed_at: 1.month.ago) }

  describe '#perform' do
    it 'enqueues refresh job for each due teammate and removes schedules' do
      CheckInHealthCacheRefreshSchedule.create!(teammate: teammate, refresh_at: 1.hour.ago)
      expect { described_class.perform_now }.to have_enqueued_job(CheckInHealthCacheRefreshJob).with(teammate.id)
      expect(CheckInHealthCacheRefreshSchedule.find_by(teammate_id: teammate.id)).to be_nil
    end

    it 'does nothing when no schedules are due' do
      CheckInHealthCacheRefreshSchedule.create!(teammate: teammate, refresh_at: 1.hour.from_now)
      expect { described_class.perform_now }.not_to have_enqueued_job(CheckInHealthCacheRefreshJob)
    end
  end
end
