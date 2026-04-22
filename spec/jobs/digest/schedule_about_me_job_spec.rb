# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::ScheduleAboutMeJob, type: :job do
  include ActiveSupport::Testing::TimeHelpers

  let(:organization) { create(:organization) }
  let(:person) { create(:person, timezone: 'America/Los_Angeles') }
  let(:teammate) do
    t = create(:company_teammate, person: person, organization: organization)
    create(:employment_tenure, teammate: t, company: organization, started_at: 1.year.ago, ended_at: nil)
    t.update!(first_employed_at: 1.year.ago)
    t
  end

  it 'enqueues weekly send job when weekday/hour match and medium is enabled' do
    prefs = UserPreference.for_person(person)
    prefs.update_preference('digest_slack', 'on')
    prefs.update_preference('about_me_weekly_day', '2') # Tuesday

    travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
      expect { described_class.perform_now }.to have_enqueued_job(Digest::SendAboutMeJob).with(teammate.id, '2025-10')
    end
  end

  it 'does not enqueue when about me weekly day is off' do
    prefs = UserPreference.for_person(person)
    prefs.update_preference('digest_slack', 'on')
    prefs.update_preference('about_me_weekly_day', 'off')

    travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
      expect { described_class.perform_now }.not_to have_enqueued_job(Digest::SendAboutMeJob)
    end
  end
end
