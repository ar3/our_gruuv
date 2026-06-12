# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::ScheduleInterestingThingsJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:organization) { create(:organization) }
  let(:person) { create(:person, timezone: 'America/Los_Angeles') }
  let(:teammate) do
    t = create(:company_teammate, person: person, organization: organization)
    create(:employment_tenure, teammate: t, company: organization, started_at: 1.year.ago, ended_at: nil)
    t.update!(first_employed_at: 1.year.ago)
    t
  end

  before do
    teammate
    allow_any_instance_of(SomethingInterestingQueryService).to receive(:total_count).and_return(2)
  end

  describe '#perform' do
    it 'enqueues SendInterestingThingsJob when opted in at 8am local on a weekday' do
      UserPreference.for_person(person).update_preference('interesting_things_digest_enabled', 'on')
      # Tuesday 8am Pacific = 2025-03-04 16:00 UTC
      travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
        expect { described_class.perform_now }.to have_enqueued_job(Digest::SendInterestingThingsJob).with(teammate.id)
      end
    end

    it 'does not enqueue when the notification is off' do
      travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
        expect { described_class.perform_now }.not_to have_enqueued_job(Digest::SendInterestingThingsJob)
      end
    end

    it 'does not enqueue when there is nothing interesting to show' do
      UserPreference.for_person(person).update_preference('interesting_things_digest_enabled', 'on')
      allow_any_instance_of(SomethingInterestingQueryService).to receive(:total_count).and_return(0)
      travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
        expect { described_class.perform_now }.not_to have_enqueued_job(Digest::SendInterestingThingsJob)
      end
    end

    it 'does not enqueue on weekends' do
      UserPreference.for_person(person).update_preference('interesting_things_digest_enabled', 'on')
      # Saturday 8am Pacific: 2025-03-08 16:00 UTC
      travel_to Time.zone.parse('2025-03-08 16:00:00 UTC') do
        expect { described_class.perform_now }.not_to have_enqueued_job(Digest::SendInterestingThingsJob)
      end
    end

    it 'does not enqueue outside the 8am local hour' do
      UserPreference.for_person(person).update_preference('interesting_things_digest_enabled', 'on')
      travel_to Time.zone.parse('2025-03-04 23:00:00 UTC') do
        expect { described_class.perform_now }.not_to have_enqueued_job(Digest::SendInterestingThingsJob)
      end
    end
  end
end
