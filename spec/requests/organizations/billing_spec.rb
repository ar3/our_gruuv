# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::Billing', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let!(:teammate) do
    create(
      :company_teammate,
      :assigned_employee,
      person: person,
      organization: organization,
      can_manage_billing: can_manage_billing
    )
  end
  let(:can_manage_billing) { false }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/billing' do
    context 'when the teammate lacks manage billing' do
      let(:billing_manager_person) { create(:person, first_name: 'Pat', preferred_name: 'Pat') }
      let!(:billing_manager) do
        create(
          :company_teammate,
          :assigned_employee,
          person: billing_manager_person,
          organization: organization,
          can_manage_billing: true
        )
      end

      it 'shows the access banner with casual names and Value link' do
        get organization_billing_path(organization)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Billing')
        expect(response.body).to include('billingPageHelp')
        expect(response.body).to include('OG is committed to bringing value')
        expect(response.body).to include(organization_value_path(organization))
        expect(response.body).to include('OG Value page')
        expect(response.body).to include('Billing can be managed by')
        expect(response.body).to include(billing_manager_person.casual_name)
        expect(response.body).not_to include('Payment cadence')
        expect(response.body).not_to include('No open invoices yet')
        expect(response.body).not_to include('stub_pay')
      end
    end

    context 'when the teammate can manage billing' do
      let(:can_manage_billing) { true }

      it 'shows the commercial billing surface with stub Pay' do
        get organization_billing_path(organization)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Upcoming PEPM')
        expect(response.body).to include('Payment cadence')
        expect(response.body).to include('Monthly (full price)')
        expect(response.body).to include('Quarterly (10% discount)')
        expect(response.body).to include('Semi-annually (20% discount)')
        expect(response.body).to include('round down to the nearest $0.50')
        expect(response.body).to include("you'll likely pay")
        expect(response.body).to include('Incomplete until')
        expect(response.body).to include('context-callout')
        expect(response.body.scan(/you'll likely pay/).size).to eq(3)
        expect(response.body.scan(/context-callout/).size).to eq(3)
        expect(response.body).to include('Open invoices')
        expect(response.body).to include('Paid invoices')
        expect(response.body).to include('No open invoices yet')
        expect(response.body).to include('stub_pay')
        expect(response.body).to include(organization_value_path(organization))
        expect(response.body).not_to include('Billing can be managed by')
      end

      it 'shows locked copy and open invoice after calculation day' do
        due_on = Date.new(2026, 12, 1)
        calculation_on = due_on - 1.week
        OrganizationBillingSetting.for_organization!(organization).update!(
          cadence: 'monthly',
          next_payment_due_on: due_on
        )
        allow(Organizations::Billing::ValueBasedPepm).to receive(:new).and_return(
          instance_double(
            Organizations::Billing::ValueBasedPepm,
            call: {
              total_value: 40.0,
              week_count: 13,
              teammate_count: 1,
              per_employee_week: 1.0,
              per_employee_month: 5.0,
              range_begin: calculation_on - 90.days,
              range_end: calculation_on
            }
          )
        )
        Organizations::Billing::LockPepm.call(
          organization: organization,
          due_on: due_on,
          as_of: calculation_on
        )

        get organization_billing_path(organization)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("you'll pay")
        expect(response.body).to include('Locked on')
        expect(response.body).to include('First lock — no prior PEPM setpoint')
        expect(response.body).to include('Incomplete until')
        expect(organization.billing_invoices.open_invoices.count).to eq(1)
        expect(response.body).not_to include('No open invoices yet')
      end
    end
  end


  describe 'PATCH /organizations/:organization_id/billing/update_cadence' do
    context 'when the teammate can manage billing' do
      let(:can_manage_billing) { true }

      it 'updates cadence' do
        patch update_cadence_organization_billing_path(organization),
              params: { organization_billing_setting: { cadence: 'quarterly' } }

        expect(response).to redirect_to(organization_billing_path(organization))
        expect(OrganizationBillingSetting.find_by!(organization: organization).cadence).to eq('quarterly')
      end
    end

    context 'when the teammate lacks manage billing' do
      it 'forbids cadence updates' do
        patch update_cadence_organization_billing_path(organization),
              params: { organization_billing_setting: { cadence: 'quarterly' } }

        expect(response).to have_http_status(:redirect)
        expect(OrganizationBillingSetting.find_by(organization: organization)).to be_nil
      end
    end
  end

  describe 'POST /organizations/:organization_id/billing/stub_pay' do
    let(:can_manage_billing) { true }

    it 'redirects with a coming-soon notice' do
      post stub_pay_organization_billing_path(organization)

      expect(response).to redirect_to(organization_billing_path(organization))
      follow_redirect!
      expect(response.body).to include('Online payment is coming soon')
    end
  end
end
