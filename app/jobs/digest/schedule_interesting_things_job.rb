# frozen_string_literal: true

module Digest
  # Runs every hour; finds teammates for whom it is 8:00 AM on a weekday in their timezone
  # and enqueues SendInterestingThingsJob for teammates who opted in and have at least one
  # interesting thing since their last visit to the Something Interesting page (or 7 days).
  class ScheduleInterestingThingsJob < ApplicationJob
    queue_as :default

    DIGEST_HOUR = 8

    def perform
      now_utc = Time.current

      CompanyTeammate.employed.includes(:person).find_each do |teammate|
        next unless teammate.organization

        person = teammate.person
        tz = person.timezone.presence
        next if tz.blank?

        prefs = UserPreference.for_person(person)
        next unless prefs.interesting_things_digest_enabled?

        local_time = now_utc.in_time_zone(tz)
        next unless local_time.hour == DIGEST_HOUR
        next unless weekday?(local_time)
        next unless has_interesting_things?(teammate)

        SendInterestingThingsJob.perform_later(teammate.id)
      end
    end

    private

    def weekday?(time)
      time.wday.between?(1, 5) # Monday-Friday
    end

    def has_interesting_things?(teammate)
      since = SomethingInterestingQueryService.baseline(teammate)
      SomethingInterestingQueryService.new(teammate: teammate, since: since).total_count.positive?
    end
  end
end
