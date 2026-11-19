# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::BillingInvoices', type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:can_manage_billing) { true }
  let!(:teammate) do
    create(
      :company_teammate,
      :assigned_employee,
      person: person,
      organization: organization,
      can_manage_billing: can_manage_billing
    )
  end
  let!(:invoice) do
    create(
      :billing_invoice,
      organization: organization,
      status: 'open',
      due_on: Date.new(2026, 11, 1),
      period_starts_on: Date.new(2026, 11, 1),
      period_ends_on: Date.new(2026, 11, 30),
      pepm: 5.0,
      teammate_count: 2,
      amount_due: 10.0,
      value_delivered_total: 40.0,
      value_based_pepm: 5.5
    )
  end

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/billing_invoices/:id' do
    it 'shows invoice details, OG Value Analysis, and Pay' do
      travel_to Date.new(2026, 11, 15) do
        get organization_billing_invoice_path(organization, invoice)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Invoice')
        expect(response.body).to include('billingInvoicePageHelp')
        expect(response.body).to include('jd-print-ready')
        expect(response.body).to include('jd-print-letterhead')
        expect(response.body).to include('Print to paper or PDF')
        expect(response.body).to include('window.print()')
        expect(response.body).to include('Based on the value delivered between')
        expect(response.body).to include('the OG cost is $5.50 per employee per month')
        expect(response.body).to include('Transparency. Clarity. Fairness. That leads to Growth.')
        expect(response.body).to include('the OG Way')
        expect(response.body).to include('that is most important')
        expect(response.body).to include('We round down to the nearest $0.50. Monthly cadence has no discount.')
        expect(response.body).to include('billing-invoice-print-caption')
        expect(response.body).to include('bi-info-circle')
        expect(response.body).to include('$5.00')
        expect(response.body).to include('/ teammate')
        expect(response.body).not_to include('Free until at least $0.50')
        expect(response.body).to include('Current PEPM')
        expect(response.body).to include('Based on average value delivered')
        expect(response.body).to include('round down to the nearest $0.50')
        expect(response.body).to include('OG cost vs value')
        expect(response.body).to include('Priced from lookback')
        expect(response.body).to include('You pay')
        expect(response.body).to include('cost savings vs delivery')
        expect(response.body).to include('Lookback')
        expect(response.body).to include('Sets what you pay')
        expect(response.body).to include('This period')
        expect(response.body).to include('Next period')
        expect(response.body).to include('Where value is heading')
        expect(response.body).to include('jd-print-screen-only')
        expect(response.body).not_to include('Prior-prior')
        expect(response.body).not_to include('Projected this period')
        expect(response.body).to include('This period is about')
        expect(response.body).to include('% complete')
        expect(response.body).to include('At this pace, by 100%')
        expect(response.body).to include('same ~90-day window used to set PEPM')
        expect(response.body).to include('pace projection to 100%')
        # In-progress marker + visible pace projection (Haml must emit these as text)
        expect(response.body).to match(/>\+</)
        expect(response.body).to match(/\(~[\d,$]+/)
        expect(response.body).to include('OG helped')
        expect(response.body).to include('Which is valued at')
        expect(response.body).to include('$10.00')
        expect(response.body).to include('stub_pay')
        expect(response.body).to include(organization_billing_path(organization))
        expect(response.body).not_to include('Impersonation only')
        expect(response.body).not_to include(update_status_organization_billing_invoice_path(organization, invoice))
      end
    end

    it 'shows free-until-value-floor copy when OG cost is $0' do
      invoice.update!(pepm: 0, value_based_pepm: 0, amount_due: 0)

      travel_to Date.new(2026, 11, 15) do
        get organization_billing_invoice_path(organization, invoice)

        expect(response.body).to include('Free until at least $0.50 per employee per month value has been achieved.')
        expect(response.body).not_to include('the OG cost is')
        expect(response.body).to include('Free / teammate')
      end
    end

    it 'shows current PEPM discount math on the invoice when cadence is quarterly' do
      OrganizationBillingSetting.for_organization!(organization).update!(cadence: 'quarterly')
      allow(Organizations::Billing::ValueBasedPepm).to receive(:new).and_return(
        instance_double(
          Organizations::Billing::ValueBasedPepm,
          call: {
            total_value: 1267.50,
            week_count: 13,
            teammate_count: 108,
            per_employee_week: 0.9,
            per_employee_month: 3.87,
            range_begin: Date.new(2026, 8, 18),
            range_end: Date.new(2026, 11, 16)
          }
        )
      )

      travel_to Date.new(2026, 11, 15) do
        get organization_billing_invoice_path(organization, invoice)

        expect(response.body).to include('Based on average value delivered')
        expect(response.body).to include('$1,267.50')
        expect(response.body).to include('108 active teammates')
        # 3.87 × 0.95 = 3.6765 → $3.68 before the $0.50 floor; charged PEPM floors to $3.50
        expect(response.body).to include('With the 5% quarterly cadence discount, that brings the per employee per month price down to $3.68.')
        expect(response.body).to include('$3.50')
      end
    end

    it 'hides Next period after the invoice period has ended' do
      # Far enough out that lookback and this period are complete.
      travel_to Date.new(2027, 2, 1) do
        get organization_billing_invoice_path(organization, invoice)

        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('Projected this period')
        expect(response.body).not_to include('activity counts so far')
        expect(response.body).to include('Cost savings vs delivery')
        expect(response.body).to include('even when delivery ends up lower than the lookback that set the price')
        expect(response.body).not_to include('Where value is heading')
        expect(response.body).not_to include('This period is about')
        expect(response.body).not_to include('At this pace, by 100%')
      end
    end

    context 'when impersonating' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:impersonating?).and_return(true)
      end

      it 'shows the manual status dropdown with open and waived' do
        get organization_billing_invoice_path(organization, invoice)

        expect(response.body).to include('Manual status')
        expect(response.body).to include('Impersonation only')
        expect(response.body).to include('open')
        expect(response.body).to include('waived')
        expect(response.body).to include(update_status_organization_billing_invoice_path(organization, invoice))
      end
    end

    context 'when the teammate lacks manage billing' do
      let(:can_manage_billing) { false }

      it 'forbids access' do
        get organization_billing_invoice_path(organization, invoice)
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST stub_pay' do
    it 'redirects with a coming-soon notice' do
      post stub_pay_organization_billing_invoice_path(organization, invoice)

      expect(response).to redirect_to(organization_billing_invoice_path(organization, invoice))
      follow_redirect!
      expect(response.body).to include('Online payment is coming soon')
    end
  end

  describe 'PATCH update_status' do
    it 'rejects manual status changes when not impersonating' do
      patch update_status_organization_billing_invoice_path(organization, invoice),
            params: { billing_invoice: { status: 'waived' } }

      expect(response).to redirect_to(organization_billing_invoice_path(organization, invoice))
      expect(invoice.reload.status).to eq('open')
    end

    context 'when impersonating' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:impersonating?).and_return(true)
      end

      it 'updates to waived' do
        patch update_status_organization_billing_invoice_path(organization, invoice),
              params: { billing_invoice: { status: 'waived' } }

        expect(response).to redirect_to(organization_billing_invoice_path(organization, invoice))
        expect(invoice.reload.status).to eq('waived')
      end

      it 'rejects automation-only statuses' do
        patch update_status_organization_billing_invoice_path(organization, invoice),
              params: { billing_invoice: { status: 'paid' } }

        expect(response).to redirect_to(organization_billing_invoice_path(organization, invoice))
        expect(invoice.reload.status).to eq('open')
      end
    end
  end

  describe 'GET /organizations/:organization_id/billing_invoices/upcoming/:due_on' do
    it 'shows likely invoice details and OG cost vs value for a future due date' do
      due_on = Date.new(2027, 1, 1)
      OrganizationBillingSetting.for_organization!(organization).update!(
        cadence: 'quarterly',
        next_payment_due_on: due_on
      )
      allow(Organizations::Billing::ValueBasedPepm).to receive(:new).and_return(
        instance_double(
          Organizations::Billing::ValueBasedPepm,
          call: {
            total_value: 100.0,
            week_count: 13,
            teammate_count: 2,
            per_employee_week: 1.0,
            per_employee_month: 4.3,
            range_begin: Date.new(2026, 9, 25),
            range_end: Date.new(2026, 12, 24)
          }
        )
      )

      travel_to Date.new(2026, 12, 1) do
        get upcoming_organization_billing_invoices_path(organization, due_on)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Upcoming invoice')
        expect(response.body).to include('Future')
        expect(response.body).to include('Likely invoice details')
        expect(response.body).to include('Likely amount due')
        expect(response.body).to include('Not due yet')
        expect(response.body).to include('OG cost vs value')
        expect(response.body).to include('Current PEPM')
        expect(response.body).not_to include('stub_pay')
      end
    end

    it 'redirects to the locked invoice when one already exists for that due date' do
      get upcoming_organization_billing_invoices_path(organization, invoice.due_on)

      expect(response).to redirect_to(organization_billing_invoice_path(organization, invoice))
    end
  end
end

