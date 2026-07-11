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

    it 'counts unique all-time publishers and observees employed during each week' do
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
      data_rows = obs_group[:rows].reject { |r| r[:separator] }
      publishers_this_week = data_rows.find { |r| r[:key] == 'unique_ogo_publishers_this_week' }
      publishers = data_rows.find { |r| r[:key] == 'unique_ogo_publishers' }
      observees_this_week = data_rows.find { |r| r[:key] == 'unique_ogo_observees_this_week' }
      observees = data_rows.find { |r| r[:key] == 'unique_ogo_observees' }

      expect(publishers_this_week[:label]).to eq('Teammates that published an OGO this week')
      expect(publishers[:label]).to eq('Teammates that published an OGO all-time')
      expect(observees_this_week[:label]).to eq('Teammates named as observees in an OGO this week')
      expect(observees[:label]).to eq('Teammates named as observees in an OGO all-time')
      expect(publishers_this_week[:weekly_values]).to eq([1, 1])
      expect(publishers[:weekly_values]).to eq([1, 1])
      expect(observees_this_week[:weekly_values]).to eq([1, 1])
      expect(observees[:weekly_values]).to eq([1, 1])
    end

    it 'shows zero for this week when activity happened only in an earlier week' do
      monday = Date.new(2026, 5, 4)
      week_starts = [monday, monday + 7]
      chart_range = monday.beginning_of_day..(monday + 13).end_of_day

      observer_person = create(:person)
      create(:teammate, organization: company, person: observer_person, first_employed_at: monday - 1.year, last_terminated_at: nil)

      obs = build(:observation, company: company, observer: observer_person, story: 'A' * 20)
      obs.save!(validate: false)
      obs.update_columns(published_at: monday.to_time + 12.hours, observed_at: monday.to_time + 12.hours)

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      publishers_this_week = result[:groups].find { |g| g[:title] == 'Observations' }[:rows]
        .reject { |r| r[:separator] }
        .find { |r| r[:key] == 'unique_ogo_publishers_this_week' }
      publishers_all_time = result[:groups].find { |g| g[:title] == 'Observations' }[:rows]
        .reject { |r| r[:separator] }
        .find { |r| r[:key] == 'unique_ogo_publishers' }

      expect(publishers_this_week[:weekly_values]).to eq([1, 0])
      expect(publishers_all_time[:weekly_values]).to eq([1, 1])
    end

    it 'carries all-time publisher counts into later weeks when they published earlier but not that week' do
      monday = Date.new(2026, 5, 4)
      week_starts = [monday, monday + 7]
      chart_range = monday.beginning_of_day..(monday + 13).end_of_day

      observer_person = create(:person)
      observee_person = create(:person)
      create(:teammate, organization: company, person: observer_person, first_employed_at: monday - 1.year, last_terminated_at: nil)
      observee_tm = create(:teammate, organization: company, person: observee_person, first_employed_at: monday - 1.year, last_terminated_at: nil)

      obs = build(:observation, company: company, observer: observer_person, story: 'A' * 20)
      obs.observees.destroy_all
      obs.observees.build(teammate: observee_tm)
      obs.save!(validate: false)
      obs.update_columns(published_at: monday.to_time + 12.hours, observed_at: monday.to_time + 12.hours)

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      obs_group = result[:groups].find { |g| g[:title] == 'Observations' }
      publishers = obs_group[:rows].reject { |r| r[:separator] }.find { |r| r[:key] == 'unique_ogo_publishers' }
      observees = obs_group[:rows].reject { |r| r[:separator] }.find { |r| r[:key] == 'unique_ogo_observees' }

      expect(publishers[:weekly_values]).to eq([1, 1])
      expect(observees[:weekly_values]).to eq([1, 1])
    end

    it 'drops all-time counts when a teammate is no longer employed during a later week' do
      monday = Date.new(2026, 6, 1)
      week_starts = [monday, monday + 7]
      chart_range = monday.beginning_of_day..(monday + 13).end_of_day

      observer_person = create(:person)
      publisher = create(
        :teammate,
        organization: company,
        person: observer_person,
        first_employed_at: monday - 1.year,
        last_terminated_at: monday + 3.days
      )

      obs = build(:observation, company: company, observer: observer_person, story: 'A' * 20)
      obs.save!(validate: false)
      obs.update_columns(published_at: monday.to_time + 12.hours, observed_at: monday.to_time + 12.hours)

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      publishers = result[:groups].find { |g| g[:title] == 'Observations' }[:rows]
        .reject { |r| r[:separator] }
        .find { |r| r[:key] == 'unique_ogo_publishers' }

      expect(publishers[:weekly_values]).to eq([1, 0])
    end

    it 'includes separator rows in the Observations section between activity and Gruuv Health blocks' do
      monday = Date.current.beginning_of_week(:monday)
      week_starts = [monday]
      chart_range = monday.beginning_of_day..(monday + 6).end_of_day

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      obs_group = result[:groups].find { |g| g[:title] == 'Observations' }

      expect(obs_group[:rows].count { |row| row[:separator] }).to eq(3)
      publishers_this_week_index = obs_group[:rows].index { |row| row[:key] == 'unique_ogo_publishers_this_week' }
      publishers_all_time_index = obs_group[:rows].index { |row| row[:key] == 'unique_ogo_publishers' }
      observees_this_week_index = obs_group[:rows].index { |row| row[:key] == 'unique_ogo_observees_this_week' }
      first_gruuv_index = obs_group[:rows].index do |row|
        row[:key]&.start_with?(Insights::OgScorecard::GruuvHealthWeekCounts::METRIC_KEY_PREFIX)
      end
      expect(publishers_this_week_index).to eq(0)
      expect(publishers_all_time_index).to eq(1)
      expect(obs_group[:rows][publishers_all_time_index + 1][:separator]).to be(true)
      expect(observees_this_week_index).to eq(publishers_all_time_index + 2)
      expect(obs_group[:rows][observees_this_week_index + 2][:separator]).to be(true)
      expect(first_gruuv_index).to eq(observees_this_week_index + 3)
    end

    it 'excludes journal (observer-only) observations from activity publisher and observee counts' do
      monday = Date.new(2026, 7, 6)
      week_starts = [monday]
      chart_range = monday.beginning_of_day..(monday + 6).end_of_day

      observer_person = create(:person)
      observee_person = create(:person)
      create(:teammate, organization: company, person: observer_person, first_employed_at: monday - 1.year, last_terminated_at: nil)
      observee_tm = create(:teammate, organization: company, person: observee_person, first_employed_at: monday - 1.year, last_terminated_at: nil)

      obs = build(
        :observation,
        company: company,
        observer: observer_person,
        story: 'A' * 20,
        privacy_level: :observer_only
      )
      obs.observees.destroy_all
      obs.observees.build(teammate: observee_tm)
      obs.save!(validate: false)
      obs.update_columns(published_at: monday.to_time + 12.hours, observed_at: monday.to_time + 12.hours)

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      data_rows = result[:groups].find { |g| g[:title] == 'Observations' }[:rows].reject { |r| r[:separator] }
      publishers_this_week = data_rows.find { |r| r[:key] == 'unique_ogo_publishers_this_week' }
      observees_this_week = data_rows.find { |r| r[:key] == 'unique_ogo_observees_this_week' }

      expect(publishers_this_week[:weekly_values]).to eq([0])
      expect(observees_this_week[:weekly_values]).to eq([0])
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

    it 'includes activity rows, teammate rows, separators, and Gruuv Health rows in the Ability Milestones section' do
      monday = Date.current.beginning_of_week(:monday)
      week_starts = [monday]
      chart_range = monday.beginning_of_day..(monday + 6).end_of_day

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      milestones_group = result[:groups].find { |g| g[:title] == 'Ability Milestones' }

      expect(milestones_group[:rows].count { |row| row[:separator] }).to eq(2)
      data_rows = milestones_group[:rows].reject { |row| row[:separator] }
      expect(data_rows.size).to eq(9)
      expect(data_rows[0][:key]).to eq('milestones_earned_this_week')
      expect(data_rows[1][:key]).to eq('milestones_earned_90_days')
      expect(data_rows[2][:key]).to eq('milestones_earned_all_time')
      expect(data_rows[3][:key]).to eq('unique_teammates_milestone_this_week')
      expect(data_rows[4][:key]).to eq('unique_teammates_milestone_90_days')
      expect(data_rows[5][:key]).to eq('unique_teammates_milestone_all_time')

      gruuv_keys = data_rows.last(3).map { |row| row[:key] }
      expect(gruuv_keys).to contain_exactly(
        Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(EngagementHealth::CATEGORY_MILESTONES, EngagementHealth::HEALTHY),
        Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(EngagementHealth::CATEGORY_MILESTONES, EngagementHealth::WARNING),
        Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(EngagementHealth::CATEGORY_MILESTONES, EngagementHealth::NEEDS_ATTENTION)
      )

      separator_indices = milestones_group[:rows].each_index.select { |i| milestones_group[:rows][i][:separator] }
      expect(separator_indices).to eq([3, 7])
    end

    it 'includes activity rows, a separator, and Gruuv Health rows in the Check-ins section' do
      monday = Date.current.beginning_of_week(:monday)
      week_starts = [monday]
      chart_range = monday.beginning_of_day..(monday + 6).end_of_day

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      check_ins_group = result[:groups].find { |g| g[:title] == 'Check-ins' }

      expect(check_ins_group[:rows].count { |row| row[:separator] }).to eq(1)
      data_rows = check_ins_group[:rows].reject { |row| row[:separator] }
      expect(data_rows.size).to eq(5)
      expect(data_rows[0][:key]).to eq('unique_teammates_check_in_finalized_this_week')
      expect(data_rows[1][:key]).to eq('unique_teammates_check_in_finalized_all_time')

      gruuv_keys = data_rows.last(3).map { |row| row[:key] }
      expect(gruuv_keys).to contain_exactly(
        Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(EngagementHealth::CATEGORY_REQUIRED_CLARITY, EngagementHealth::HEALTHY),
        Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(EngagementHealth::CATEGORY_REQUIRED_CLARITY, EngagementHealth::WARNING),
        Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(EngagementHealth::CATEGORY_REQUIRED_CLARITY, EngagementHealth::NEEDS_ATTENTION)
      )

      separator_index = check_ins_group[:rows].index { |row| row[:separator] }
      expect(separator_index).to eq(2)
    end

    it 'includes a separator between Gruuv Health and goal activity rows in the Goals section' do
      monday = Date.current.beginning_of_week(:monday)
      week_starts = [monday]
      chart_range = monday.beginning_of_day..(monday + 6).end_of_day

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      goals_group = result[:groups].find { |g| g[:title] == 'Goals' }

      expect(goals_group[:rows].count { |row| row[:separator] }).to eq(1)
      first_gruuv_index = goals_group[:rows].index do |row|
        row[:key]&.start_with?(Insights::OgScorecard::GruuvHealthWeekCounts::METRIC_KEY_PREFIX)
      end
      separator_index = goals_group[:rows].index { |row| row[:separator] }
      first_activity_index = goals_group[:rows].index { |row| row[:key] == 'unique_teammates_active_goal' }

      expect(first_gruuv_index).to eq(0)
      expect(separator_index).to eq(3)
      expect(first_activity_index).to eq(4)
    end

    it 'includes a Gruuv Health group with population rows from EngagementHealth' do
      monday = Date.current.beginning_of_week(:monday)
      week_starts = [monday]
      chart_range = monday.beginning_of_day..(monday + 6).end_of_day

      teammate = create(:teammate, organization: company, first_employed_at: monday - 1.year, last_terminated_at: nil)
      EngagementHealth::CATEGORIES.each do |category|
        EngagementHealthStatus.create!(
          teammate: teammate,
          organization: company,
          level: "category",
          category: category,
          status: category == EngagementHealth::CATEGORY_OGO_GIVEN ? EngagementHealth::NEEDS_ATTENTION : EngagementHealth::HEALTHY,
          inputs: {},
          computed_at: Time.current
        )
      end

      result = described_class.new(company: company, week_starts: week_starts, chart_range: chart_range).call
      group = result[:groups].find { |g| g[:title] == 'Observations' }

      expect(group).to be_present
      gruuv_rows = group[:rows].reject { |row| row[:separator] }.select { |row| row[:key].start_with?('gruuv_health_') }
      expect(gruuv_rows.size).to eq(6)
      expect(result[:gruuv_health_backfill_enqueued]).to be(false)

      ogo_given_needs_attention = group[:rows].reject { |row| row[:separator] }.find do |row|
        row[:key] == Insights::OgScorecard::GruuvHealthWeekCounts.metric_key(
          EngagementHealth::CATEGORY_OGO_GIVEN,
          EngagementHealth::NEEDS_ATTENTION
        )
      end
      expect(ogo_given_needs_attention[:weekly_values]).to eq([1])
      expect(ogo_given_needs_attention[:label]).to eq('Teammates that have Needs Attention OGOs Given')
      expect(ogo_given_needs_attention[:threshold_hint]).to include('90 days ago or never')
    end
  end
end
