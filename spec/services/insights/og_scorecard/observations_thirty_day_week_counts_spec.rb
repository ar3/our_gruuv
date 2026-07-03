# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Insights::OgScorecard::ObservationsThirtyDayWeekCounts do
  let(:company) { create(:company) }
  let(:monday) { Date.new(2026, 4, 6) }
  let(:week_starts) { [monday] }

  around do |example|
    Time.use_zone('UTC') { example.run }
  end

  def publish_observation(observer_person:, observee_teammate:, published_at:)
    obs = build(:observation, company: company, observer: observer_person, story: 'A' * 20)
    obs.observees.destroy_all
    obs.observees.build(teammate: observee_teammate)
    obs.save!(validate: false)
    obs.update_columns(published_at: published_at, observed_at: published_at)
    obs
  end

  describe '#call' do
    it 'counts unique publishers and observees in rolling 30 days ending Sunday' do
      observer_person = create(:person)
      observee_person = create(:person)
      publisher = create(:teammate, organization: company, person: observer_person, first_employed_at: monday - 1.year)
      observee = create(:teammate, organization: company, person: observee_person, first_employed_at: monday - 1.year)
      sunday = monday + 6.days

      publish_observation(
        observer_person: observer_person,
        observee_teammate: observee,
        published_at: (sunday - 25.days).to_time + 12.hours
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_ogo_publishers_30_days][monday]).to eq(1)
      expect(result[:unique_ogo_observees_30_days][monday]).to eq(1)
    end

    it 'excludes observations published before the 30-day window' do
      observer_person = create(:person)
      observee_person = create(:person)
      create(:teammate, organization: company, person: observer_person, first_employed_at: monday - 1.year)
      observee = create(:teammate, organization: company, person: observee_person, first_employed_at: monday - 1.year)
      sunday = monday + 6.days

      publish_observation(
        observer_person: observer_person,
        observee_teammate: observee,
        published_at: (sunday - 35.days).to_time + 12.hours
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_ogo_publishers_30_days][monday]).to eq(0)
      expect(result[:unique_ogo_observees_30_days][monday]).to eq(0)
    end

    it 'carries prior-week activity into later weeks while still inside 30 days' do
      observer_person = create(:person)
      observee_person = create(:person)
      create(:teammate, organization: company, person: observer_person, first_employed_at: monday - 1.year)
      observee = create(:teammate, organization: company, person: observee_person, first_employed_at: monday - 1.year)
      week_starts = [monday, monday + 7]

      publish_observation(
        observer_person: observer_person,
        observee_teammate: observee,
        published_at: monday.to_time + 12.hours
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_ogo_publishers_30_days][monday]).to eq(1)
      expect(result[:unique_ogo_observees_30_days][monday + 7]).to eq(1)
    end

    it 'includes observations published exactly 30 days before Sunday' do
      observer_person = create(:person)
      observee_person = create(:person)
      create(:teammate, organization: company, person: observer_person, first_employed_at: monday - 1.year)
      observee = create(:teammate, organization: company, person: observee_person, first_employed_at: monday - 1.year)
      sunday = monday + 6.days

      publish_observation(
        observer_person: observer_person,
        observee_teammate: observee,
        published_at: (sunday - 30.days).to_time + 12.hours
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_ogo_publishers_30_days][monday]).to eq(1)
    end

    it 'excludes journal (observer-only) observations' do
      observer_person = create(:person)
      observee_person = create(:person)
      create(:teammate, organization: company, person: observer_person, first_employed_at: monday - 1.year)
      observee = create(:teammate, organization: company, person: observee_person, first_employed_at: monday - 1.year)
      sunday = monday + 6.days

      obs = build(
        :observation,
        company: company,
        observer: observer_person,
        story: 'A' * 20,
        privacy_level: :observer_only
      )
      obs.observees.destroy_all
      obs.observees.build(teammate: observee)
      obs.save!(validate: false)
      obs.update_columns(published_at: sunday.to_time, observed_at: sunday.to_time)

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_ogo_publishers_30_days][monday]).to eq(0)
    end

    it 'excludes publishers who were not employed during the week' do
      observer_person = create(:person)
      observee_person = create(:person)
      create(
        :teammate,
        organization: company,
        person: observer_person,
        first_employed_at: monday - 1.year,
        last_terminated_at: monday - 1.day
      )
      observee = create(:teammate, organization: company, person: observee_person, first_employed_at: monday - 1.year)
      sunday = monday + 6.days

      publish_observation(
        observer_person: observer_person,
        observee_teammate: observee,
        published_at: sunday.to_time
      )

      result = described_class.call(company: company, week_starts: week_starts)

      expect(result[:unique_ogo_publishers_30_days][monday]).to eq(0)
    end
  end
end
