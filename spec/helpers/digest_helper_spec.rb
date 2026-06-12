# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DigestHelper, type: :helper do
  describe '#weekly_digest_summary_sentence' do
    it 'describes a single digest on a weekday' do
      sentence = helper.weekly_digest_summary_sentence(one_on_one_on: true, about_me_on: false, weekly_day: '2')
      expect(sentence).to eq('Will send 1:1 guide on Tuesday')
    end

    it 'describes both digests' do
      sentence = helper.weekly_digest_summary_sentence(one_on_one_on: true, about_me_on: true, weekly_day: '2')
      expect(sentence).to eq('Will send 1:1 guide and About Me reminder on Tuesday')
    end
  end

  describe '#weekly_reminder_configured?' do
    it 'is true when a digest is on and a day is set' do
      expect(helper.weekly_reminder_configured?(one_on_one_on: true, about_me_on: false, weekly_day: '2')).to be(true)
    end

    it 'is false when no digest is selected' do
      expect(helper.weekly_reminder_configured?(one_on_one_on: false, about_me_on: false, weekly_day: '2')).to be(false)
    end
  end

  describe '#notification_nudge_summary_sentence' do
    let(:person) { create(:person) }
    let(:prefs) { UserPreference.for_person(person) }

    it 'summarizes multiple enabled notification types' do
      prefs.update_preference('gsd_digest_enabled', 'on')
      prefs.update_preference('interesting_things_digest_enabled', 'on')
      prefs.update_preference('about_me_weekly_day', '1')
      prefs.update_preference('one_on_one_digest_enabled', 'on')

      sentence = helper.notification_nudge_summary_sentence(casual_name: 'Alex', prefs: prefs, gsd_label: 'GSD')
      expect(sentence).to eq('Alex has notifications configured for GSD, Interesting Things, and weekly 1:1 guide on Mondays.')
    end

    it 'returns nil when nothing is enabled' do
      expect(helper.notification_nudge_summary_sentence(casual_name: 'Alex', prefs: prefs)).to be_nil
    end
  end

  describe '#notification_nudge_partial_sentence' do
    let(:person) { create(:person) }
    let(:prefs) { UserPreference.for_person(person) }

    it 'lists what is still off and the value of each' do
      prefs.update_preference('gsd_digest_enabled', 'on')

      sentence = helper.notification_nudge_partial_sentence(casual_name: 'Alex', prefs: prefs, gsd_label: 'GSD')
      expect(sentence).to eq('Still off for Alex: Interesting Things updates and weekly recap digests.')
    end
  end
end
