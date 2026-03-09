# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckInHealthCacheRefreshJob, type: :job do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization, first_employed_at: 1.month.ago) }

  describe '#perform' do
    it 'builds and saves cache for the teammate' do
      expect { described_class.perform_now(teammate.id) }.to change(CheckInHealthCache, :count).by(1)
      cache = CheckInHealthCache.find_by(teammate: teammate, organization: organization)
      expect(cache).to be_present
      expect(cache.payload).to have_key('position')
    end

    it 'does nothing when teammate does not exist' do
      expect { described_class.perform_now(999_999) }.not_to change(CheckInHealthCache, :count)
    end
  end

  describe 'enqueue' do
    it 'enqueues with teammate_id' do
      expect { described_class.perform_later(teammate.id) }.to have_enqueued_job(described_class).with(teammate.id)
    end
  end
end
