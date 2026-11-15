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

  def breakdown_for(values_by_key)
    Organizations::Billing::ValueDrivers::DRIVERS.map do |driver|
      {
        key: driver[:key],
        label: driver[:label],
        activity_count: 0,
        value_sum: values_by_key.fetch(driver[:key], 0.0)
      }
    end
  end

  it 'projects linear per-employee growth when prior improved over prior-prior' do
    allow(drivers).to receive(:breakdown) do |range|
      if range.begin == Date.new(2026, 10, 1)
        breakdown_for(stories: 10.0, stand: 5.0, growth: 2.0, goals: 1.0, consultations: 2.0)
      elsif range.begin == Date.new(2026, 11, 1)
        breakdown_for(stories: 14.0, stand: 5.0, growth: 3.0, goals: 1.0, consultations: 2.0)
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
    expect(stories.prior_prior_value).to eq(5.0)   # 10 / 2 teammates
    expect(stories.prior_prior_total).to eq(10.0)
    expect(stories.prior_value).to eq(7.0)         # 14 / 2
    expect(stories.prior_total).to eq(14.0)
    expect(stories.current_value).to eq(9.0)       # 7 + (7-5)
    expect(stories.current_total).to eq(18.0)

    stand = result.rows.find { |row| row.key == :stand }
    expect(stand.current_value).to eq(2.5)         # flat 5/2

    expect(result.teammate_count).to eq(2)
    expect(result.total_sums[:current]).to eq(result.rows.sum { |row| row.current_total.to_f })

    expect(result.columns.map(&:starts_on)).to eq([
      Date.new(2026, 10, 1),
      Date.new(2026, 11, 1),
      Date.new(2026, 12, 1)
    ])
  end

  it 'uses flat prior per-employee value when progress is not positive' do
    allow(drivers).to receive(:breakdown) do |range|
      case range.begin
      when Date.new(2026, 10, 1)
        breakdown_for(stories: 12.0, stand: 0, growth: 0, goals: 0, consultations: 0)
      when Date.new(2026, 11, 1)
        breakdown_for(stories: 8.0, stand: 0, growth: 0, goals: 0, consultations: 0)
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
    expect(stories.prior_value).to eq(4.0)       # 8 / 2
    expect(stories.current_value).to eq(4.0)
  end

  it 'shows actual per-employee value once the period has fully ended' do
    allow(drivers).to receive(:breakdown) do |range|
      case range.begin
      when Date.new(2026, 10, 1)
        breakdown_for(stories: 10.0, stand: 0, growth: 0, goals: 0, consultations: 0)
      when Date.new(2026, 11, 1)
        breakdown_for(stories: 14.0, stand: 0, growth: 0, goals: 0, consultations: 0)
      when Date.new(2026, 12, 1)
        breakdown_for(stories: 6.0, stand: 0, growth: 0, goals: 0, consultations: 0)
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
    expect(stories.current_value).to eq(3.0)  # 6 / 2 actual, not the 9.0 projection
    expect(stories.current_total).to eq(6.0)
  end
end
