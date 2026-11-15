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

  it 'pace-projects an in-progress prior period before trending the upcoming future column' do
    allow(drivers).to receive(:breakdown) do |range|
      case [range.begin.to_date, range.end.to_date]
      when [Date.new(2026, 10, 1), Date.new(2026, 10, 31)]
        breakdown_for({ stories: 10 }, teammate_by_key: { stories: 3 })
      when [Date.new(2026, 11, 1), Date.new(2026, 11, 20)]
        # Prior column clipped so-far through as_of
        breakdown_for({ stories: 12 }, teammate_by_key: { stories: 4 })
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

    expect(result.columns[0].complete?).to eq(true)
    expect(result.columns[1].in_progress?).to eq(true)
    expect(result.columns[2].upcoming?).to eq(true)
    expect(result.columns[1].period_progress).to be_within(0.001).of(20.0 / 30)

    stories = result.rows.find { |row| row.key == :stories }
    expect(stories.prior_prior.activity_count).to eq(10)
    expect(stories.prior.activity_count).to eq(12) # so-far display
    # Pace prior to 100%: 12 / (20/30) = 18, then trend vs prior-prior: 18 + (18-10) = 26
    expect(stories.current.activity_count).to eq(26)
    expect(stories.current.value_sum).to eq(13.0) # 26 * 0.5

    clipped_weeks = Organizations::Billing::ValueBasedPepm.week_count_for(Date.new(2026, 11, 1)..Date.new(2026, 11, 20))
    expect(result.totals[:prior].value_sum).to eq(6.0) # 12 * 0.5 so-far
    expect(result.totals[:prior].week_count).to eq(clipped_weeks)
    expect(result.totals[:current].value_sum).to eq(13.0)
  end

  it 'uses so-far actuals on the current column while that period is in progress' do
    allow(drivers).to receive(:breakdown) do |range|
      case [range.begin.to_date, range.end.to_date]
      when [Date.new(2026, 10, 1), Date.new(2026, 10, 31)]
        breakdown_for({ stories: 10 }, teammate_by_key: { stories: 3 })
      when [Date.new(2026, 11, 1), Date.new(2026, 11, 30)]
        breakdown_for({ stories: 14 }, teammate_by_key: { stories: 4 })
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

    expect(result.columns[2].in_progress?).to eq(true)
    stories = result.rows.find { |row| row.key == :stories }
    expect(stories.current.activity_count).to eq(8)

    clipped = Date.new(2026, 12, 1)..Date.new(2026, 12, 15)
    weeks = Organizations::Billing::ValueBasedPepm.week_count_for(clipped)
    expect(result.totals[:current].value_sum).to eq(4.0)
    expect(result.totals[:current].week_count).to eq(weeks)
    expect(result.totals[:current].pepm).to eq(((4.0 / weeks / 2) * 4.3).round(2))
  end

  it 'shows full-period actuals once every column has ended' do
    allow(drivers).to receive(:breakdown) do |range|
      case [range.begin.to_date, range.end.to_date]
      when [Date.new(2026, 10, 1), Date.new(2026, 10, 31)]
        breakdown_for({ stories: 10 }, teammate_by_key: { stories: 2 })
      when [Date.new(2026, 11, 1), Date.new(2026, 11, 30)]
        breakdown_for({ stories: 14 }, teammate_by_key: { stories: 3 })
      when [Date.new(2026, 12, 1), Date.new(2026, 12, 31)]
        breakdown_for({ stories: 6 }, teammate_by_key: { stories: 1 })
      else
        breakdown_for({})
      end
    end

    result = described_class.call(
      organization: organization,
      cadence: 'monthly',
      period_due_on: Date.new(2026, 12, 1),
      as_of: Date.new(2027, 1, 1)
    )

    expect(result.complete?).to eq(true)
    weeks = Organizations::Billing::ValueBasedPepm.week_count_for(Date.new(2026, 12, 1)..Date.new(2026, 12, 31))
    expect(result.totals[:current].value_sum).to eq(3.0)
    expect(result.totals[:current].pepm).to eq(((3.0 / weeks / 2) * 4.3).round(2))
  end
end
