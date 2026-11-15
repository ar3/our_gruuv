# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::ValueAnalysisTable do
  let(:organization) { create(:organization) }
  let(:drivers) { instance_double(Organizations::Billing::ValueDrivers) }

  before do
    create(:company_teammate, :assigned_employee, organization: organization)
    create(:company_teammate, :assigned_employee, organization: organization)
    allow(Organizations::Billing::ValueDrivers).to receive(:new).with(organization).and_return(drivers)
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

  it 'projects linear activity growth when prior improved over prior-prior' do
    allow(drivers).to receive(:breakdown) do |range|
      if range.begin == Date.new(2026, 10, 1)
        breakdown_for(
          { stories: 10, stand: 5, growth: 2, goals: 4, consultations: 2 },
          teammate_by_key: { stories: 3, stand: 2, growth: 1, goals: 2, consultations: 1 }
        )
      elsif range.begin == Date.new(2026, 11, 1)
        breakdown_for(
          { stories: 14, stand: 5, growth: 3, goals: 4, consultations: 2 },
          teammate_by_key: { stories: 4, stand: 2, growth: 2, goals: 2, consultations: 1 }
        )
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

    expect(result.projected?).to eq(true)
    expect(result.columns[2].label).to eq('Projected this period')

    stories = result.rows.find { |row| row.key == :stories }
    expect(stories.prior_prior.activity_count).to eq(10)
    expect(stories.prior_prior.teammate_count).to eq(3)
    expect(stories.prior_prior.value_sum).to eq(5.0) # 10 * 0.5
    expect(stories.prior.activity_count).to eq(14)
    expect(stories.current.activity_count).to eq(18) # 14 + (14-10)
    expect(stories.current.teammate_count).to eq(5)  # 4 + (4-3)
    expect(stories.current.value_sum).to eq(9.0)     # 18 * 0.5

    stand = result.rows.find { |row| row.key == :stand }
    expect(stand.current.activity_count).to eq(5) # flat

    # Overall PEPM = sum(value_sums) / employed (2), not sum of per-driver PEPMs
    prior_value_sum = 14 * 0.5 + 5 * 0.5 + 3 * 1.0 + 4 * 0.25 + 2 * 1.0
    expect(result.totals[:prior].value_sum).to eq(prior_value_sum)
    expect(result.totals[:prior].pepm).to eq((prior_value_sum / 2).round(2))
    expect(result.teammate_count).to eq(2)
  end

  it 'uses flat prior activity when progress is not positive' do
    allow(drivers).to receive(:breakdown) do |range|
      case range.begin
      when Date.new(2026, 10, 1)
        breakdown_for({ stories: 12 }, teammate_by_key: { stories: 3 })
      when Date.new(2026, 11, 1)
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
    stories = result.rows.find { |row| row.key == :stories }
    expect(stories.prior.activity_count).to eq(8)
    expect(stories.current.activity_count).to eq(8)
    expect(stories.current.teammate_count).to eq(2)
  end

  it 'shows actual activity once the period has fully ended' do
    allow(drivers).to receive(:breakdown) do |range|
      case range.begin
      when Date.new(2026, 10, 1)
        breakdown_for({ stories: 10 }, teammate_by_key: { stories: 2 })
      when Date.new(2026, 11, 1)
        breakdown_for({ stories: 14 }, teammate_by_key: { stories: 3 })
      when Date.new(2026, 12, 1)
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

    expect(result.projected?).to eq(false)
    expect(result.columns[2].key).to eq(:actual)
    expect(result.columns[2].label).to eq('Actual this period')

    stories = result.rows.find { |row| row.key == :stories }
    expect(stories.current.activity_count).to eq(6)
    expect(stories.current.teammate_count).to eq(1)
    expect(stories.current.value_sum).to eq(3.0)
    expect(result.totals[:current].pepm).to eq(1.5) # 3.0 / 2 employed
  end
end
