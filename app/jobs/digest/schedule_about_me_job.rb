# frozen_string_literal: true

module Digest
  class ScheduleAboutMeJob < ApplicationJob
    queue_as :default

    DIGEST_HOUR = 8

    def perform
      now_utc = Time.current

      CompanyTeammate.employed.includes(:person).find_each do |teammate|
        person = teammate.person
        next if person.timezone.blank?

        prefs = UserPreference.for_person(person)
        weekly_day = prefs.preference(:about_me_weekly_day).to_s
        next if weekly_day == 'off' || weekly_day.blank?
        next unless weekly_day.match?(/\A[0-6]\z/)
        next unless digest_enabled_for_any_medium?(prefs)

        local_time = now_utc.in_time_zone(person.timezone)
        next unless local_time.hour == DIGEST_HOUR
        next unless local_time.wday == weekly_day.to_i

        week_key = local_time.strftime('%G-%V')
        next if prefs.preference(:about_me_last_sent_week).to_s == week_key

        Digest::SendAboutMeJob.perform_later(teammate.id, week_key)
      end
    end

    private

    def digest_enabled_for_any_medium?(prefs)
      [prefs.effective_digest_slack(nil), prefs.effective_digest_email, prefs.effective_digest_sms(nil)].include?('on')
    end
  end
end
