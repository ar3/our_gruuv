# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::ValueAnalysisTable do
  let(:organization) { create(:organization) }
  let(:drivers) { instance_double(Organizations::Billing::ValueDrivers) }

  before do
    create(:company_teammate, :assigned_employee, organization: organization)
    create(:company_teammate, :assigned_employee, organization: organization)
    allow(Organizations::Billing::ValueDrivers).to receive(:new).with(organization).and_return(drivers)
    allow(drivers).to receive(:total_value) do |range|
      drivers.breakdown(range).sum { |row| row[:value_sum].to_f }
    end
  end

  def breakdown_for(activity_by_key, teammate_by_key: {})
    Organizations::Billing::ValueDrivers::DRIVERS.map do |driver|
      activity = activity_by_key.fetch(driver[:key], 0)
      {
        key: driver[:key],
        label: driver[:label],
        activity_count: activity,
        teammate_count: teammate_by_key.fetch(driver[:key], activity.positive? ? 1 : 0),
        value_sum: activity * driver[:unit_value]
      }
    end
  end

  it 'uses a fixed ~90-day lookback column and projects an upcoming current period from it' do
    # period_due_on Dec 1 → calculation Nov 24; as_of Nov 20 → lookback ends Nov 20
    lookback = Date.new(2026, 8, 22)..Date.new(2026, 11, 20)
    prior_lookback = Date.new(2026, 5, 23)..Date.new(2026, 8, 21)

    allow(drivers).to receive(:breakdown) do |range|
      case [range.begin.to_date, range.end.to_date]
      when [lookback.begin, lookback.end]
        breakdown_for({ stories: 30 }, teammate_by_key: { stories: 6 })
      when [prior_lookback.begin, prior_lookback.end]
        breakdown_for({ stories: 20 }, teammate_by_key: { stories: 4 })
      else
        breakdown_for({})
      end
    end

    result = described_class.call(
      organization: organization,
      cadence: 'monthly',
      period_due_on: Date.new(2026, 12, 1),
      as_of: Date.new(2026, 11, 20)
    )

    lookback_col = result.column_for(:lookback)
    current_col = result.column_for(:current)
    future_col = result.column_for(:future)

    expect(lookback_col.starts_on).to eq(lookback.begin)
    expect(lookback_col.ends_on).to eq(lookback.end)
    expect(lookback_col.complete?).to eq(true)
    expect(lookback_col.activity_scale).to eq(1.0)

    expect(current_col.starts_on).to eq(Date.new(2026, 12, 1))
    expect(current_col.ends_on).to eq(Date.new(2026, 12, 31))
    expect(current_col.upcoming?).to eq(true)
    expect(current_col.activity_scale).to be_within(0.01).of(91.0 / 31)

    expect(future_col.starts_on).to eq(Date.new(2027, 1, 1))
    expect(future_col.upcoming?).to eq(true)

    stories = result.rows.find { |row| row.key == :stories }
    expect(stories.lookback.activity_count).to eq(30)
    # Trend lookback vs prior: 30 + (30-20) = 40, then scale to December length: 40 * 31/91
    expect(stories.current.activity_count).to eq(((40.0 * 31) / 91).round)
    expect(result.totals[:lookback].value_sum).to eq(15.0) # 30 * 0.5
    expect(result.totals[:current].value_sum).to eq((stories.current.activity_count * 0.5).round(2))
  end

  it 'scales monthly this-period activity relative to lookback day count' do
    lookback = Date.new(2026, 8, 26)..Date.new(2026, 11, 24)

    allow(drivers).to receive(:breakdown) do |range|
      case [range.begin.to_date, range.end.to_date]
      when [lookback.begin, lookback.end]
        breakdown_for({ stories: 30 }, teammate_by_key: { stories: 6 })
      when [Date.new(2026, 12, 1), Date.new(2026, 12, 15)]
        breakdown_for({ stories: 8 }, teammate_by_key: { stories: 2 })
      else
        breakdown_for({})
      end
    end

    result = described_class.call(
      organization: organization,
      cadence: 'monthly',
      period_due_on: Date.new(2026, 12, 1),
      as_of: Date.new(2026, 12, 15)
    )

    current_col = result.column_for(:current)
    expect(current_col.in_progress?).to eq(true)
    expect(current_col.activity_scale).to be_within(0.01).of(91.0 / 31)

    stories = result.rows.find { |row| row.key == :stories }
    expect(stories.current.activity_count).to eq(8) # period-native so-far

    clipped = Date.new(2026, 12, 1)..Date.new(2026, 12, 15)
    weeks = Organizations::Billing::ValueBasedPepm.week_count_for(clipped)
    expect(result.totals[:current].value_sum).to eq(4.0)
    expect(result.totals[:current].week_count).to eq(weeks)
    expect(result.totals[:current].pepm).to eq(((4.0 / weeks / 2) * 4.3).round(2))
  end

  it 'locks lookback to calculation day once that day has passed' do
    lookback = Date.new(2026, 8, 26)..Date.new(2026, 11, 24)

    allow(drivers).to receive(:breakdown) do |range|
      case [range.begin.to_date, range.end.to_date]
      when [lookback.begin, lookback.end]
        breakdown_for({ stories: 30 }, teammate_by_key: { stories: 5 })
      when [Date.new(2026, 12, 1), Date.new(2026, 12, 31)]
        breakdown_for({ stories: 6 }, teammate_by_key: { stories: 1 })
      when [Date.new(2027, 1, 1), Date.new(2027, 1, 31)]
        breakdown_for({ stories: 4 }, teammate_by_key: { stories: 1 })
      else
        breakdown_for({})
      end
    end

    result = described_class.call(
      organization: organization,
      cadence: 'monthly',
      period_due_on: Date.new(2026, 12, 1),
      as_of: Date.new(2027, 2, 1)
    )

    expect(result.column_for(:lookback).starts_on).to eq(lookback.begin)
    expect(result.column_for(:lookback).ends_on).to eq(lookback.end)
    expect(result.complete?).to eq(true)
    weeks = Organizations::Billing::ValueBasedPepm.week_count_for(Date.new(2026, 12, 1)..Date.new(2026, 12, 31))
    expect(result.totals[:current].value_sum).to eq(3.0)
    expect(result.totals[:current].pepm).to eq(((3.0 / weeks / 2) * 4.3).round(2))
  end

  it 'keeps quarterly this-period activity scale near 1.0' do
    # due Apr 1 → calculation Mar 25; as_of Mar 25
    lookback = Date.new(2025, 12, 25)..Date.new(2026, 3, 25)
    current = Date.new(2026, 4, 1)..Date.new(2026, 6, 30)

    allow(drivers).to receive(:breakdown) do |range|
      case [range.begin.to_date, range.end.to_date]
      when [lookback.begin, lookback.end]
        breakdown_for({ stories: 90 }, teammate_by_key: { stories: 10 })
      when [current.begin, current.end]
        breakdown_for({ stories: 90 }, teammate_by_key: { stories: 10 })
      else
        breakdown_for({})
      end
    end

    result = described_class.call(
      organization: organization,
      cadence: 'quarterly',
      period_due_on: Date.new(2026, 4, 1),
      as_of: Date.new(2026, 7, 1)
    )

    expect(result.column_for(:current).activity_scale).to be_within(0.05).of(1.0)
  end
end
