# frozen_string_literal: true

module Digest
  # Runs every hour; finds teammates for whom it is 8:00 AM in their timezone and
  # enqueues SendDigestJob for teammates who turned on the GSD notification and
  # have at least one GSD item.
  class ScheduleDigestsJob < ApplicationJob
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
        next unless prefs.gsd_digest_enabled?

        local_time = now_utc.in_time_zone(tz)
        next unless local_time.hour == DIGEST_HOUR
        next unless weekday?(local_time)
        next unless has_gsd_items?(teammate)

        SendDigestJob.perform_later(teammate.id)
      end
    end

    private

    def weekday?(time)
      time.wday.between?(1, 5) # Monday-Friday
    end

    def has_gsd_items?(teammate)
      GetShitDoneQueryService.new(teammate: teammate).all_pending_items[:total_pending].to_i.positive?
    end
  end
end
