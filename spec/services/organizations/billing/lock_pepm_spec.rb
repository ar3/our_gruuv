# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::LockPepm do
  let(:organization) { create(:organization) }
  let(:due_on) { Date.new(2026, 12, 1) }
  let(:calculation_on) { due_on - 1.week }

  before do
    create(:company_teammate, :assigned_employee, organization: organization)
    OrganizationBillingSetting.for_organization!(organization).update!(
      cadence: 'monthly',
      next_payment_due_on: due_on
    )
  end

  it 'skips before calculation day' do
    result = described_class.call(
      organization: organization,
      due_on: due_on,
      as_of: calculation_on - 1.day
    )

    expect(result.created?).to eq(false)
    expect(result.skipped_reason).to eq('calculation_day_not_reached')
    expect(organization.billing_invoices).to be_empty
  end

  it 'locks pepm and creates an open invoice on calculation day' do
    allow(Organizations::Billing::ValueBasedPepm).to receive(:new).and_return(
      instance_double(
        Organizations::Billing::ValueBasedPepm,
        call: {
          total_value: 120.0,
          week_count: 13,
          teammate_count: 2,
          per_employee_week: 4.0,
          per_employee_month: 17.2,
          range_begin: calculation_on - 90.days,
          range_end: calculation_on
        }
      )
    )

    result = described_class.call(
      organization: organization,
      due_on: due_on,
      as_of: calculation_on
    )

    expect(result.created?).to eq(true)
    invoice = result.invoice
    expect(invoice).to be_open
    expect(invoice.due_on).to eq(due_on)
    expect(invoice.pepm).to eq(17.0) # 17.2 rounded down to nearest $0.50
    expect(invoice.teammate_count).to eq(2)
    expect(invoice.amount_due).to eq(34.0) # min(17*2*1, 120) then half-dollar floor
    expect(invoice.value_delivered_total).to eq(120.0)

    setting = OrganizationBillingSetting.find_by!(organization: organization)
    expect(setting.locked_pepm).to eq(17.0)
    expect(setting.next_payment_due_on).to eq(due_on)
  end

  it 'caps amount_due at value delivered' do
    allow(Organizations::Billing::ValueBasedPepm).to receive(:new).and_return(
      instance_double(
        Organizations::Billing::ValueBasedPepm,
        call: {
          total_value: 10.0,
          week_count: 13,
          teammate_count: 2,
          per_employee_week: 4.0,
          per_employee_month: 17.2,
          range_begin: calculation_on - 90.days,
          range_end: calculation_on
        }
      )
    )

    invoice = described_class.call(
      organization: organization,
      due_on: due_on,
      as_of: calculation_on
    ).invoice

    expect(invoice.amount_due).to eq(10.0)
  end

  it 'is idempotent for the same due date' do
    allow(Organizations::Billing::ValueBasedPepm).to receive(:new).and_return(
      instance_double(
        Organizations::Billing::ValueBasedPepm,
        call: {
          total_value: 50.0,
          week_count: 13,
          teammate_count: 1,
          per_employee_week: 1.0,
          per_employee_month: 4.3,
          range_begin: calculation_on - 90.days,
          range_end: calculation_on
        }
      )
    )

    first = described_class.call(organization: organization, due_on: due_on, as_of: calculation_on)
    second = described_class.call(organization: organization, due_on: due_on, as_of: calculation_on)

    expect(first.created?).to eq(true)
    expect(second.created?).to eq(false)
    expect(organization.billing_invoices.count).to eq(1)
  end
end
