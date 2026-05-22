# frozen_string_literal: true

namespace :digest do
  desc 'Set weekly About Me / 1:1 digest toggles for existing users (1:1 on, About Me off when a day is scheduled)'
  task migrate_weekly_digest_toggles: :environment do
    UserPreference.find_each do |pref|
      day = pref.preference(:about_me_weekly_day).to_s
      if day.match?(/\A[0-6]\z/)
        pref.update_preference('one_on_one_digest_enabled', 'on')
        pref.update_preference('about_me_digest_enabled', 'off')
      else
        pref.update_preference('one_on_one_digest_enabled', 'off')
        pref.update_preference('about_me_digest_enabled', 'off')
      end
    end
    puts "Migrated #{UserPreference.count} user preference records."
  end
end
