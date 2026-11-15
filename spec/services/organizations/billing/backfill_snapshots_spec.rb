# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organizations::Billing::BackfillSnapshots do
  let(:organization) { create(:organization) }
  let(:as_of) { Date.new(2026, 11, 14) }

  before do
    create(:company_teammate, :assigned_employee, organization: organization)
    OrganizationBillingSetting.for_organization!(organization).update!(
      cadence: 'monthly',
      next_payment_due_on: Date.new(2026, 12, 1)
    )
    allow(Organizations::Billing::ValueBasedPepm).to receive(:new).and_return(
      instance_double(
        Organizations::Billing::ValueBasedPepm,
        call: {
          total_value: 30.0,
          week_count: 13,
          teammate_count: 1,
          per_employee_week: 1.0,
          per_employee_month: 4.3,
          range_begin: as_of - 90.days,
          range_end: as_of
        }
      )
    )
  end

  it 'creates open historical invoices for past periods' do
    result = described_class.call(organization: organization, count: 3, as_of: as_of)

    expect(result.created_count).to eq(3)
    expect(organization.billing_invoices.open_invoices.count).to eq(3)
    expect(organization.billing_invoices.paid_invoices).to be_empty
    expect(OrganizationBillingSetting.find_by!(organization: organization).next_payment_due_on).to eq(Date.new(2026, 12, 1))
  end

  it 'skips when invoices already exist' do
    create(:billing_invoice, organization: organization, due_on: Date.new(2026, 10, 1), status: 'paid', paid_at: 1.month.ago)

    result = described_class.call(organization: organization, as_of: as_of)

    expect(result.created_count).to eq(0)
    expect(result.skipped_reason).to eq('already_has_invoices')
    expect(organization.billing_invoices.count).to eq(1)
  end
end
