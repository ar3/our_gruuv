# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::PreviousDueDates do
  it 'returns prior monthly due dates' do
    expect(described_class.call(cadence: 'monthly', before: Date.new(2026, 12, 1), count: 3)).to eq([
      Date.new(2026, 11, 1),
      Date.new(2026, 10, 1),
      Date.new(2026, 9, 1)
    ])
  end

  it 'returns prior quarterly due dates' do
    expect(described_class.call(cadence: 'quarterly', before: Date.new(2027, 1, 1), count: 3)).to eq([
      Date.new(2026, 10, 1),
      Date.new(2026, 7, 1),
      Date.new(2026, 4, 1)
    ])
  end
end
