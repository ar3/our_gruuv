# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::NextDueDate do
  it 'returns the first of the next month for monthly when not already the first' do
    expect(described_class.call(cadence: 'monthly', from: Date.new(2026, 11, 14))).to eq(Date.new(2026, 12, 1))
  end

  it 'returns today when monthly and already the first' do
    expect(described_class.call(cadence: 'monthly', from: Date.new(2026, 11, 1))).to eq(Date.new(2026, 11, 1))
  end

  it 'returns the next quarterly date' do
    expect(described_class.call(cadence: 'quarterly', from: Date.new(2026, 11, 14))).to eq(Date.new(2027, 1, 1))
    expect(described_class.call(cadence: 'quarterly', from: Date.new(2026, 4, 1))).to eq(Date.new(2026, 4, 1))
  end

  it 'returns the next semiannual date' do
    expect(described_class.call(cadence: 'semiannual', from: Date.new(2026, 3, 15))).to eq(Date.new(2026, 7, 1))
    expect(described_class.call(cadence: 'semiannual', from: Date.new(2026, 8, 1))).to eq(Date.new(2027, 1, 1))
  end
end
