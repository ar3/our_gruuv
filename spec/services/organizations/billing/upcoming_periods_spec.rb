# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::UpcomingPeriods do
  it 'returns the next three monthly due dates with calculation dates one week earlier' do
    periods = described_class.call(cadence: 'monthly', from: Date.new(2026, 11, 14), count: 3)

    expect(periods.map(&:due_on)).to eq([
      Date.new(2026, 12, 1),
      Date.new(2027, 1, 1),
      Date.new(2027, 2, 1)
    ])
    expect(periods.map(&:calculation_on)).to eq([
      Date.new(2026, 11, 24),
      Date.new(2026, 12, 25),
      Date.new(2027, 1, 25)
    ])
    expect(periods.map(&:calculation_passed?)).to eq([false, false, false])
  end

  it 'marks calculation_passed when the calculation date is today or earlier' do
    periods = described_class.call(cadence: 'monthly', from: Date.new(2026, 11, 24), count: 1)

    expect(periods.first.due_on).to eq(Date.new(2026, 12, 1))
    expect(periods.first.calculation_passed?).to eq(true)
  end

  it 'uses a stored first due date when it is still upcoming' do
    periods = described_class.call(
      cadence: 'quarterly',
      from: Date.new(2026, 11, 14),
      count: 3,
      first_due_on: Date.new(2027, 1, 1)
    )

    expect(periods.map(&:due_on)).to eq([
      Date.new(2027, 1, 1),
      Date.new(2027, 4, 1),
      Date.new(2027, 7, 1)
    ])
  end
end
