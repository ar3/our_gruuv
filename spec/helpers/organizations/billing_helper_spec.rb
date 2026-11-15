# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::BillingHelper, type: :helper do
  describe '#billing_value_outcome_popover' do
    it 'builds the Value-page stories sentence with monetary value' do
      copy = helper.billing_value_outcome_popover(
        key: :stories,
        teammate_count: 97,
        activity_count: 546,
        value_sum: 273.0,
        company_name: 'CareerPlug'
      )

      expect(copy).to include('OG helped 97 teammates Capture 546 CareerPlug Stories')
      expect(copy).to include('Which is valued at $273.00')
    end

    it 'builds the consultations sentence' do
      copy = helper.billing_value_outcome_popover(
        key: :consultations,
        teammate_count: 10,
        activity_count: 162,
        value_sum: 162.0,
        company_name: 'CareerPlug'
      )

      expect(copy).to include('OG provided 10 teammates with 162 completed Consult OG consultations')
      expect(copy).to include('Which is valued at $162.00')
    end
  end

  describe '#billing_in_progress_activity_popover' do
    it 'includes percent complete and a pace estimate at 100%' do
      cell = Organizations::Billing::ValueAnalysisTable::Cell.new(
        activity_count: 100,
        teammate_count: 10,
        value_sum: 50.0
      )

      copy = helper.billing_in_progress_activity_popover(
        key: :stories,
        cell: cell,
        company_name: 'CareerPlug',
        period_progress: 0.5
      )

      expect(copy).to include('This period is about 50% complete')
      expect(copy).to include('OG helped 10 teammates Capture 100 CareerPlug Stories')
      expect(copy).to include('At this pace, by 100% that may be')
      expect(copy).to include('Capture 200 CareerPlug Stories')
      expect(copy).to include('valued at $100.00')
    end
  end
end
