# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::TeammateDigestStatusService do
  let(:organization) { create(:organization) }
  let(:person) { create(:person, timezone: 'America/Los_Angeles') }
  let(:teammate) do
    t = create(:company_teammate, person: person, organization: organization)
    create(:employment_tenure, teammate: t, company: organization, started_at: 1.year.ago, ended_at: nil)
    t.update!(first_employed_at: 1.year.ago)
    t
  end

  subject(:service) do
    described_class.new(
      teammate: teammate,
      organization: organization,
      gsd_label: 'GSD',
      gsd_pending_count: 2
    )
  end

  describe '#gsd_blockers' do
    it 'lists blockers when prerequisites are missing' do
      person.update!(timezone: nil)
      UserPreference.for_person(person).update_preference('gsd_digest_enabled', 'off')

      expect(service.gsd_blockers).to include(
        a_string_matching(/timezone/),
        a_string_matching(/turned off/),
        a_string_matching(/Connect Slack/)
      )
    end

    it 'lists no pending items when count is zero' do
      empty = described_class.new(teammate: teammate, organization: organization, gsd_pending_count: 0)
      expect(empty.gsd_blockers).to include(a_string_matching(/No items in/))
    end
  end

  describe '#one_on_one_blockers' do
    it 'includes weekly day and toggle issues' do
      prefs = UserPreference.for_person(person)
      prefs.update_preference('about_me_weekly_day', 'off')
      prefs.update_preference('one_on_one_digest_enabled', 'off')

      expect(service.one_on_one_blockers).to include(
        a_string_matching(/weekly reminder day/),
        a_string_matching(/1:1 guide digest is turned off/),
        a_string_matching(/Connect Slack/)
      )
    end
  end

  describe '#interesting_things_blockers' do
    it 'notes when the notification is off' do
      empty = described_class.new(
        teammate: teammate,
        organization: organization,
        interesting_pending_count: 0
      )
      expect(empty.interesting_things_blockers).to include(a_string_matching(/turned off/))
    end

    it 'does not treat an empty interesting-things list as a blocker when enabled' do
      prefs = UserPreference.for_person(person)
      prefs.update_preference('interesting_things_digest_enabled', 'on')

      with_counts = described_class.new(
        teammate: teammate,
        organization: organization,
        interesting_pending_count: 0
      )
      expect(with_counts.interesting_things_blockers).not_to include(a_string_matching(/Nothing new/))
    end
  end

  describe '#recent_events' do
    it 'maps root digest notifications into events' do
      notification = create(
        :notification,
        notifiable: teammate,
        notification_type: 'one_on_one_digest',
        status: 'sent_successfully',
        main_thread_id: nil,
        created_at: 1.day.ago
      )
      create(
        :notification,
        notifiable: teammate,
        notification_type: 'one_on_one_digest',
        status: 'sent_successfully',
        main_thread: notification,
        created_at: 1.day.ago
      )

      events = service.recent_events(weeks: 3)
      expect(events.size).to eq(1)
      expect(events.first.label).to eq('1:1 guide')
      expect(events.first.status).to eq('sent_successfully')
    end
  end

  describe '#schedule_diagnosis' do
    include ActiveSupport::Testing::TimeHelpers

    it 'notes wrong weekday and missing toggle' do
      prefs = UserPreference.for_person(person)
      prefs.update_preference('about_me_weekly_day', '2')
      prefs.update_preference('one_on_one_digest_enabled', 'off')
      prefs.update_preference('digest_slack', 'on')

      travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do # Tuesday 8am Pacific
        diagnosis = service.schedule_diagnosis
        expect(diagnosis).to include(a_string_matching(/one_on_one_digest_enabled is off/))
      end
    end
  end

  describe '#already_sent_this_week?' do
    include ActiveSupport::Testing::TimeHelpers

    it 'returns true when preference week matches current iso week' do
      travel_to Time.zone.parse('2025-03-04 16:00:00 UTC') do
        week_key = Time.current.in_time_zone('America/Los_Angeles').strftime('%G-%V')
        UserPreference.for_person(person).update_preference('one_on_one_last_sent_week', week_key)
        expect(service.already_sent_this_week?(:one_on_one)).to be(true)
      end
    end
  end
end
