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

  describe '#billing_in_progress_pepm_popover' do
    it 'pace-projects PEPM with full-period weeks, not so-far week_count' do
      total_cell = Organizations::Billing::ValueAnalysisTable::TotalCell.new(
        pepm: 0.26,
        value_sum: 10.0,
        week_count: 3, # so-far weeks (clipped)
        teammate_count: 10,
        per_employee_week: 0.06
      )

      copy = helper.billing_in_progress_pepm_popover(
        total_cell: total_cell,
        period_progress: 0.5,
        full_week_count: 5
      )

      # extrapolated total 20 / 5 weeks / 10 EE * 4.3 = 1.72 — not 20/3/10*4.3
      expect(copy).to include('At this pace, by 100% that may be $1.72 / EE')
      expect(copy).not_to include('$2.87 / EE')
    end
  end

  describe '#billing_invoice_value_lookback_popover' do
    it 'explains lookback-based PEPM in OG voice' do
      copy = helper.billing_invoice_value_lookback_popover

      expect(copy).to include('Transparency. Clarity. Fairness. That leads to Growth. That\'s the OG Way.')
      expect(copy).to include('last ~90 days')
      expect(copy).to include('upcoming period')
      expect(copy).to include('that is most important')
    end
  end

  describe 'cost vs value framing helpers' do
    let(:current_col) do
      Organizations::Billing::ValueAnalysisTable::PeriodColumn.new(
        key: :current,
        label: nil,
        starts_on: Date.new(2026, 12, 1),
        ends_on: Date.new(2026, 12, 31),
        status: :complete,
        period_progress: 1.0,
        activity_scale: 3.0
      )
    end
    let(:total_cell) do
      Organizations::Billing::ValueAnalysisTable::TotalCell.new(
        pepm: 2.0,
        value_sum: 40.0,
        week_count: 4,
        teammate_count: 2,
        per_employee_week: 0.5
      )
    end
    let(:analysis) do
      Organizations::Billing::ValueAnalysisTable::Result.new(
        columns: [current_col],
        rows: [],
        totals: { current: total_cell },
        teammate_count: 2
      )
    end
    let(:period) do
      Organizations::Billing::PeriodViews::View.new(
        due_on: Date.new(2026, 12, 1),
        calculation_on: Date.new(2026, 11, 24),
        locked?: true,
        pepm: 5.0,
        amount_due: 10.0,
        prior_pepm: nil,
        value_delivered_total: 25.0,
        teammate_count: 2,
        incomplete?: false,
        value_analysis: analysis
      )
    end

    it 'reads lookback value from the period and savings vs this-period delivery' do
      expect(helper.billing_analysis_lookback_value(period)).to eq(25.0)
      expect(helper.billing_analysis_this_period_value(period)).to eq(40.0)
      expect(helper.billing_analysis_this_period_value_likely?(period)).to eq(false)
      expect(helper.billing_analysis_savings_vs_delivery(period)).to eq(30.0)
    end

    it 'pace-projects this-period value while the period is in progress' do
      current_col.status = :in_progress
      current_col.period_progress = 0.5
      total_cell.value_sum = 20.0

      expect(helper.billing_analysis_this_period_value(period)).to eq(40.0)
      expect(helper.billing_analysis_this_period_value_likely?(period)).to eq(true)
      expect(helper.billing_analysis_savings_vs_delivery(period)).to eq(30.0)
    end

    it 'floors savings at zero when you pay more than this-period value' do
      total_cell.value_sum = 5.0

      expect(helper.billing_analysis_savings_vs_delivery(period)).to eq(0.0)
    end
  end
end
