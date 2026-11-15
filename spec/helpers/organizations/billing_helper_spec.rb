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
end
