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
end
