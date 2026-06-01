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
        next unless slack_enabled_for_employee_or_manager?(teammate, prefs)

        local_time = now_utc.in_time_zone(person.timezone)
        next unless local_time.hour == DIGEST_HOUR
        next unless local_time.wday == weekly_day.to_i

        week_key = local_time.strftime('%G-%V')

        unless prefs.preference(:about_me_last_sent_week).to_s == week_key
          next unless prefs.weekly_digest_enabled?(:about_me_digest_enabled)

          Digest::SendAboutMeJob.perform_later(teammate.id, week_key)
        end

        unless prefs.preference(:one_on_one_last_sent_week).to_s == week_key
          next unless prefs.weekly_digest_enabled?(:one_on_one_digest_enabled)

          Digest::SendOneOnOneDigestJob.perform_later(teammate.id, week_key)
        end
      end
    end

    private

    def slack_enabled_for_employee_or_manager?(employee_teammate, employee_prefs)
      return true if employee_prefs.effective_digest_slack(nil) == 'on'

      manager = employee_teammate.active_employment_tenure&.manager_teammate
      return false unless manager

      manager_prefs = UserPreference.for_person(manager.person)
      manager_prefs.effective_digest_slack(nil) == 'on'
    end
  end
end
