# frozen_string_literal: true

require 'rails_helper'
require 'set'

RSpec.describe Insights::OgScorecardBuilder do
  let(:company) { create(:company) }

  around do |example|
    Time.use_zone('UTC') { example.run }
  end

  describe '#call' do
    it 'counts teammates employed through each Sunday (hire date, no termination)' do
      monday = Date.new(2026, 1, 5)
      week_starts = [monday, monday + 7]
      chart_range = monday.beginning_of_day..(monday + 13).end_of_day

      create(:teammate, organization: company, first_employed_at: monday - 30.days, last_terminated_at: nil)

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      row = result[:groups].find { |g| g[:title] == 'Teammates' }[:rows].first

      expect(row[:weekly_values]).to eq([1, 1])
      expect(row[:six_week_avg]).to eq(1.0)
    end

    it 'excludes teammates not yet hired at end of week and includes them after hire' do
      monday = Date.new(2026, 2, 2)
      week_starts = [monday, monday + 7]
      chart_range = monday.beginning_of_day..(monday + 13).end_of_day

      create(:teammate, organization: company, first_employed_at: monday + 10.days, last_terminated_at: nil)

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      row = result[:groups].find { |g| g[:title] == 'Teammates' }[:rows].first

      expect(row[:weekly_values]).to eq([0, 1])
      expect(row[:six_week_avg]).to eq(0.5)
    end

    it 'counts unique publishers and observees by published_at week' do
      monday = Date.new(2026, 3, 2)
      week_starts = [monday, monday + 7]
      chart_range = monday.beginning_of_day..(monday + 13).end_of_day

      observer_person = create(:person)
      observee_person = create(:person)
      create(:teammate, organization: company, person: observer_person, first_employed_at: monday - 1.year, last_terminated_at: nil)
      observee_tm = create(:teammate, organization: company, person: observee_person, first_employed_at: monday - 1.year, last_terminated_at: nil)

      obs1 = build(:observation, company: company, observer: observer_person, story: 'A' * 20)
      obs1.observees.destroy_all
      obs1.observees.build(teammate: observee_tm)
      obs1.save!(validate: false)
      obs1.update_columns(published_at: monday.to_time + 12.hours, observed_at: monday.to_time + 12.hours)

      obs2 = build(:observation, company: company, observer: observer_person, story: 'B' * 20)
      obs2.observees.destroy_all
      obs2.observees.build(teammate: observee_tm)
      obs2.save!(validate: false)
      obs2.update_columns(published_at: (monday + 7.days).to_time + 12.hours, observed_at: (monday + 7.days).to_time + 12.hours)

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      obs_group = result[:groups].find { |g| g[:title] == 'Observations' }
      publishers = obs_group[:rows].find { |r| r[:key] == 'unique_ogo_publishers' }
      observees = obs_group[:rows].find { |r| r[:key] == 'unique_ogo_observees' }

      expect(publishers[:weekly_values]).to eq([1, 1])
      expect(observees[:weekly_values]).to eq([1, 1])
    end

    it 'limits metrics to filtered teammate ids' do
      monday = Date.new(2026, 4, 6)
      week_starts = [monday]
      chart_range = monday.beginning_of_day..(monday + 6).end_of_day

      included = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
      create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)

      result = described_class.new(
        company: company,
        week_starts: week_starts,
        chart_range: chart_range,
        teammate_ids: Set[included.id]
      ).call
      row = result[:groups].find { |g| g[:title] == 'Teammates' }[:rows].first

      expect(row[:weekly_values]).to eq([1])
    end
  end
end
