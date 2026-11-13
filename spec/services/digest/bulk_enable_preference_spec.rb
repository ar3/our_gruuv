# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Digest::BulkEnablePreference do
  let(:organization) { create(:organization) }

  def employed_teammate(person: create(:person))
    teammate = create(:company_teammate, person: person, organization: organization)
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    teammate
  end

  describe '.eligible_counts / #call' do
    it 'enables GSD for employed teammates who are off and have never explicitly set it' do
      eligible = employed_teammate
      already_on = employed_teammate
      UserPreference.for_person(already_on.person).update_preference('gsd_digest_enabled', 'on')
      opted_out = employed_teammate
      UserPreference.for_person(opted_out.person).record_digest_toggle!('gsd_digest_enabled', 'off')
      terminated = create(:company_teammate, person: create(:person), organization: organization)
      terminated.update!(first_employed_at: 1.year.ago, last_terminated_at: 1.day.ago)

      counts = described_class.eligible_counts(company: organization)
      expect(counts['gsd']).to eq(1)

      result = described_class.call(company: organization, kind: 'gsd')
      expect(result.enabled_count).to eq(1)
      expect(UserPreference.for_person(eligible.person).gsd_digest_enabled?).to be(true)
      expect(UserPreference.for_person(eligible.person).digest_explicitly_set?('gsd_digest_enabled')).to be(false)
      expect(UserPreference.for_person(opted_out.person).gsd_digest_enabled?).to be(false)
      expect(UserPreference.for_person(terminated.person).gsd_digest_enabled?).to be(false)
    end

    it 'enables Interesting Things the same way' do
      eligible = employed_teammate
      counts = described_class.eligible_counts(company: organization)
      expect(counts['interesting_things']).to eq(1)

      described_class.call(company: organization, kind: 'interesting_things')
      expect(UserPreference.for_person(eligible.person).interesting_things_digest_enabled?).to be(true)
    end

    it 'enables 1:1 guide and defaults weekly day to Monday when unset' do
      eligible = employed_teammate
      UserPreference.for_person(eligible.person).update_preference('one_on_one_digest_enabled', 'off')
      keeps_day = employed_teammate
      prefs = UserPreference.for_person(keeps_day.person)
      prefs.update_preference('one_on_one_digest_enabled', 'off')
      prefs.update_preference('about_me_weekly_day', '3')

      result = described_class.call(company: organization, kind: 'one_on_one')
      expect(result.enabled_count).to eq(2)

      eligible_prefs = UserPreference.for_person(eligible.person)
      expect(eligible_prefs.weekly_digest_enabled?(:one_on_one_digest_enabled)).to be(true)
      expect(eligible_prefs.preference(:about_me_weekly_day)).to eq('1')

      keeps_day_prefs = UserPreference.for_person(keeps_day.person)
      expect(keeps_day_prefs.weekly_digest_enabled?(:one_on_one_digest_enabled)).to be(true)
      expect(keeps_day_prefs.preference(:about_me_weekly_day)).to eq('3')
    end

    it 'skips 1:1 when the person already has it on via default' do
      employed_teammate
      expect(described_class.eligible_counts(company: organization)['one_on_one']).to eq(0)
    end

    it 'raises for unknown kinds' do
      expect {
        described_class.call(company: organization, kind: 'nope')
      }.to raise_error(ArgumentError, /Unknown digest kind/)
    end
  end
end
