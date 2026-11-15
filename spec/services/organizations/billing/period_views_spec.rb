# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::PeriodViews do
  let(:organization) { create(:organization) }
  let(:due_on) { Date.new(2026, 12, 1) }
  let(:live_metrics) do
    {
      total_value: 40.0,
      week_count: 13,
      teammate_count: 2,
      per_employee_week: 1.0,
      per_employee_month: 5.0,
      range_begin: Date.new(2026, 8, 26),
      range_end: Date.new(2026, 11, 24)
    }
  end

  before do
    OrganizationBillingSetting.for_organization!(organization).update!(
      cadence: 'monthly',
      next_payment_due_on: due_on
    )
  end

  it 'marks locked periods from invoices and keeps later periods incomplete with live QBR numbers' do
    create(
      :billing_invoice,
      organization: organization,
      due_on: due_on,
      period_starts_on: due_on,
      period_ends_on: Date.new(2026, 12, 31),
      pepm: 5.0,
      amount_due: 10.0,
      teammate_count: 2,
      value_delivered_total: 40.0,
      cadence: 'monthly'
    )

    views = described_class.call(
      organization: organization,
      cadence: 'monthly',
      live_pepm: 7.5,
      live_metrics: live_metrics,
      months_in_period: 1,
      first_due_on: due_on,
      from: Date.new(2026, 11, 24),
      count: 2
    )

    expect(views.first.locked?).to eq(true)
    expect(views.first.pepm).to eq(5.0)
    expect(views.first.incomplete?).to eq(false)
    expect(views.first.value_analysis).to be_present
    expect(views.second.locked?).to eq(false)
    expect(views.second.pepm).to eq(7.5)
    expect(views.second.amount_due).to eq(15.0) # min(7.5*2*1, 40)
    expect(views.second.value_delivered_total).to eq(40.0)
    expect(views.second.prior_pepm).to eq(5.0)
    expect(views.second.incomplete?).to eq(true)
    expect(views.second.value_analysis).to be_nil
  end
end

