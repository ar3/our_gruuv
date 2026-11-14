# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::PeriodViews do
  let(:organization) { create(:organization) }
  let(:due_on) { Date.new(2026, 12, 1) }

  before do
    OrganizationBillingSetting.for_organization!(organization).update!(
      cadence: 'monthly',
      next_payment_due_on: due_on
    )
  end

  it 'marks locked periods from invoices and keeps later periods incomplete' do
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
      first_due_on: due_on,
      from: Date.new(2026, 11, 24),
      count: 2
    )

    expect(views.first.locked?).to eq(true)
    expect(views.first.pepm).to eq(5.0)
    expect(views.first.incomplete?).to eq(false)
    expect(views.second.locked?).to eq(false)
    expect(views.second.pepm).to eq(7.5)
    expect(views.second.incomplete?).to eq(true)
  end
end
