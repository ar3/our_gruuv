# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::ScheduleDigestsJob, type: :job do
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
    create(:teammate_identity, :slack, teammate: teammate, uid: 'U123')
  end

  describe '#perform' do
    it 'enqueues nothing when no teammate has digest at 8am in their timezone' do
      # 3pm LA = not 8am
      travel_to Time.zone.parse('2025-03-04 23:00:00 UTC') do
        expect { described_class.perform_now }.not_to have_enqueued_job(Digest::SendDigestJob)
      end
    end

    it 'enqueues SendDigestJob for teammate with digest_slack daily when it is 8am in their timezone' do
      UserPreference.for_person(person).update_preference('digest_slack', 'daily')
      # 8am Pacific = 16:00 UTC (DST varies; use a time that is 8am in LA)
      travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
        expect { described_class.perform_now }.to have_enqueued_job(Digest::SendDigestJob).with(teammate.id)
      end
    end

    it 'enqueues SendDigestJob for teammate with digest_slack weekly when it is Monday 8am in their timezone' do
      UserPreference.for_person(person).update_preference('digest_slack', 'weekly')
      # Monday 8am Pacific: 2025-03-03 16:00 UTC
      travel_to Time.zone.parse('2025-03-03 16:00:00 UTC') do
        expect { described_class.perform_now }.to have_enqueued_job(Digest::SendDigestJob).with(teammate.id)
      end
    end

    it 'does not enqueue when digest_slack weekly but not Monday in their timezone' do
      UserPreference.for_person(person).update_preference('digest_slack', 'weekly')
      # Tuesday 8am Pacific
      travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
        expect { described_class.perform_now }.not_to have_enqueued_job(Digest::SendDigestJob)
      end
    end

    it 'skips teammate with blank timezone' do
      person.update!(timezone: nil)
      UserPreference.for_person(person).update_preference('digest_slack', 'daily')
      travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
        expect { described_class.perform_now }.not_to have_enqueued_job(Digest::SendDigestJob)
      end
    end

    it 'skips when all digest channels are off' do
      UserPreference.for_person(person).update_preference('digest_slack', 'off')
      UserPreference.for_person(person).update_preference('digest_email', 'off')
      UserPreference.for_person(person).update_preference('digest_sms', 'off')
      travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
        expect { described_class.perform_now }.not_to have_enqueued_job(Digest::SendDigestJob)
      end
    end
  end
end
