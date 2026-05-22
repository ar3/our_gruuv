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

  it 'enqueues both weekly digest jobs when weekday/hour match and medium is enabled' do
    prefs = UserPreference.for_person(person)
    prefs.update_preference('digest_slack', 'on')
    prefs.update_preference('about_me_weekly_day', '2') # Tuesday

    travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
      expect { described_class.perform_now }
        .to have_enqueued_job(Digest::SendAboutMeJob).with(teammate.id, '2025-10')
        .and have_enqueued_job(Digest::SendOneOnOneDigestJob).with(teammate.id, '2025-10')
    end
  end

  it 'does not enqueue when about me weekly day is off' do
    prefs = UserPreference.for_person(person)
    prefs.update_preference('digest_slack', 'on')
    prefs.update_preference('about_me_weekly_day', 'off')

    travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
      expect { described_class.perform_now }
        .not_to have_enqueued_job(Digest::SendAboutMeJob)
      expect { described_class.perform_now }
        .not_to have_enqueued_job(Digest::SendOneOnOneDigestJob)
    end
  end

  it 'does not enqueue About Me when about me digest toggle is off' do
    prefs = UserPreference.for_person(person)
    prefs.update_preference('digest_slack', 'on')
    prefs.update_preference('about_me_weekly_day', '2')
    prefs.update_preference('about_me_digest_enabled', 'off')
    prefs.update_preference('one_on_one_digest_enabled', 'on')

    travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
      expect { described_class.perform_now }.not_to have_enqueued_job(Digest::SendAboutMeJob)
    end
  end

  it 'respects weekly digest toggle preferences' do
    prefs = UserPreference.for_person(person)
    prefs.update_preference('about_me_digest_enabled', 'off')
    prefs.update_preference('one_on_one_digest_enabled', 'on')

    job = described_class.new
    expect(job.send(:weekly_digest_enabled?, prefs, :about_me_digest_enabled)).to be(false)
    expect(job.send(:weekly_digest_enabled?, prefs, :one_on_one_digest_enabled)).to be(true)
  end

  it 'enqueues when employee slack is off but manager slack is on' do
    manager_person = create(:person)
    manager = create(:company_teammate, person: manager_person, organization: organization)
    manager.update!(first_employed_at: 1.year.ago)
    teammate.active_employment_tenure.update!(manager_teammate: manager)

    employee_prefs = UserPreference.for_person(person)
    employee_prefs.update_preference('digest_slack', 'off')
    employee_prefs.update_preference('about_me_weekly_day', '2')
    UserPreference.for_person(manager_person).update_preference('digest_slack', 'on')

    travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
      expect { described_class.perform_now }
        .to have_enqueued_job(Digest::SendAboutMeJob).with(teammate.id, '2025-10')
        .and have_enqueued_job(Digest::SendOneOnOneDigestJob).with(teammate.id, '2025-10')
    end
  end
end
