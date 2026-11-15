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
      value_delivered_total: 40.0
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
        expect(response.body).to include('OG Value Analysis')
        expect(response.body).to include('Projected this period')
        expect(response.body).not_to include('Actual this period')
        expect(response.body).to include('> / EE<')
        expect(response.body).to include('/ EE means per employee per month')
        expect(response.body).to include('OG helped')
        expect(response.body).to include('Which is valued at')
        expect(response.body).to include('$10.00')
        expect(response.body).to include('stub_pay')
        expect(response.body).to include(organization_billing_path(organization))
        expect(response.body).not_to include('Impersonation only')
        expect(response.body).not_to include(update_status_organization_billing_invoice_path(organization, invoice))
      end
    end

    it 'shows actual this-period value after the invoice period has ended' do
      travel_to Date.new(2026, 12, 2) do
        get organization_billing_invoice_path(organization, invoice)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Actual this period')
        expect(response.body).not_to include('Projected this period')
        expect(response.body).to include('even if that is less than what was paid for')
        expect(response.body).not_to include('This is an estimated projection of the value')
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
end

