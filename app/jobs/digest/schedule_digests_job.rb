# frozen_string_literal: true

module Digest
  # Runs every hour; finds teammates for whom it is 8:00 AM in their timezone and
  # enqueues SendDigestJob for teammates who have at least one enabled medium and
  # at least one GSD item.
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
        next unless digest_enabled_for_any_medium?(prefs)

        local_time = now_utc.in_time_zone(tz)
        next unless local_time.hour == DIGEST_HOUR
        next unless weekday?(local_time)
        next unless has_gsd_items?(teammate)

        SendDigestJob.perform_later(teammate.id)
      end
    end

    private

    def digest_enabled_for_any_medium?(prefs)
      [prefs.effective_digest_slack(nil), prefs.effective_digest_email, prefs.effective_digest_sms(nil)].include?('on')
    end

    def weekday?(time)
      time.wday.between?(1, 5) # Monday-Friday
    end

    def has_gsd_items?(teammate)
      GetShitDoneQueryService.new(teammate: teammate).all_pending_items[:total_pending].to_i.positive?
    end
  end
end
