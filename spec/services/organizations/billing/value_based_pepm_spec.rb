# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::ValueBasedPepm do
  describe '.week_count_for' do
    it 'matches Value-page uniq beginning_of_week counting' do
      range = Date.new(2026, 12, 1)..Date.new(2026, 12, 31)
      expected = (range.begin..range.end).map(&:beginning_of_week).uniq.size
      expect(described_class.week_count_for(range)).to eq(expected)
    end
  end

  describe '.metrics' do
    it 'uses value ÷ weeks ÷ teammates then monthly approx like the Value page' do
      range = Date.new(2026, 11, 1)..Date.new(2026, 11, 30)
      weeks = described_class.week_count_for(range)
      metrics = described_class.metrics(value_sum: 86.0, range: range, teammate_count: 2)

      expect(metrics[:week_count]).to eq(weeks)
      expect(metrics[:teammate_count]).to eq(2)
      expect(metrics[:per_employee_week]).to eq(86.0 / weeks / 2)
      expect(metrics[:per_employee_month]).to eq((86.0 / weeks / 2) * 4.3)
    end
  end
end
