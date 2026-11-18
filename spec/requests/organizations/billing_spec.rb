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

      it 'shows the commercial billing surface with incomplete QBRs' do
        get organization_billing_path(organization)

        expect(response).to have_http_status(:success)
        expect(response.body).to include('Upcoming PEPM')
        expect(response.body).to include('Payment cadence')
        expect(response.body).to include('Monthly (full price)')
        expect(response.body).to include('Quarterly (10% discount)')
        expect(response.body).to include('Semi-annually (20% discount)')
        expect(response.body).to include('The current average value is')
        expect(response.body).to include('per employee per month')
        expect(response.body).not_to include('cadence discount, that brings the per employee per month price down to')
        expect(response.body).to include('round down to the nearest $0.50')
        expect(response.body).to include("you'll likely pay")
        expect(response.body).to include('OG cost vs value')
        expect(response.body).to include('(incomplete)')
        expect(response.body).to include('Priced from lookback')
        expect(response.body).to include('Likely value this period')
        expect(response.body).to include('You pay')
        expect(response.body).to include('Likely cost savings vs delivery')
        expect(response.body).to include('Lookback')
        expect(response.body).to include('Sets what you pay')
        expect(response.body).to include('This period')
        expect(response.body).to include("Value while you're on this invoice")
        expect(response.body).to include('Next period')
        expect(response.body).to include('Where value is heading')
        expect(response.body).not_to include('Prior-prior')
        expect(response.body).not_to include('Projected this period')
        expect(response.body).not_to include('Actual this period')
        expect(response.body).to include('/ EE')
        expect(response.body).to include('OG helped')
        expect(response.body).to include('Which is valued at')
        expect(response.body).to include('Capture our Stories')
        expect(response.body).to include('same ~90-day window used to set PEPM')
        expect(response.body).to include('active teammate')
        # Incomplete next due: lookback may still be open (+), this/next often upcoming (~).
        expect(response.body).to match(/>~</)
        expect(response.body).to match(/\(~[\d,$]+|~\d|~\$/)
        expect(response.body).to include('Incomplete until')
        expect(response.body).to include('context-callout')
        expect(response.body.scan(/you'll likely pay/).size).to eq(3)
        expect(response.body.scan(/qbr-snapshot/).size).to eq(1)
        expect(response.body).to include('Open invoices')
        expect(response.body).to include('Closed invoices')
        expect(response.body).to include('No open invoices yet')
        expect(response.body).to include('No closed invoices yet')
        expect(response.body).not_to include('stub_pay')
        expect(response.body).to include(organization_value_path(organization))
        expect(response.body).not_to include('Billing can be managed by')
        expect(response.body).not_to include('Create historical billing snapshots')
      end

      it 'shows the one-time historical snapshot button when value exists without invoices' do
        allow(Organizations::Billing::ValueBasedPepm).to receive(:new).and_return(
          instance_double(
            Organizations::Billing::ValueBasedPepm,
            call: {
              total_value: 40.0,
              week_count: 13,
              teammate_count: 1,
              per_employee_week: 1.0,
              per_employee_month: 5.0,
              range_begin: 90.days.ago.to_date,
              range_end: Date.current
            }
          )
        )

        get organization_billing_path(organization)

        expect(response.body).to include('Create historical billing snapshots')
        expect(response.body).to include('no historical billing snapshots yet')
      end

      it 'explains current average PEPM and the cadence discount when not monthly' do
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

        get organization_billing_path(organization)

        expect(response.body).to include('Based on average value delivered')
        expect(response.body).to include('$1,267.50')
        expect(response.body).to include('108 active teammates')
        expect(response.body).to include('The current average value is')
        expect(response.body).to include('$3.87')
        expect(response.body).to include('per employee per month')
        # 3.87 × 0.9 = 3.483 → $3.48 before the $0.50 floor (display); charged PEPM floors to $3.00
        expect(response.body).to include('With the 10% quarterly cadence discount, that brings the per employee per month price down to $3.48.')
        expect(response.body).to include('$3.00')
        expect(response.body).to include('/ teammate')
      end

      it 'shows free-until copy when floored PEPM is $0 and discount cents before the floor' do
        OrganizationBillingSetting.for_organization!(organization).update!(cadence: 'quarterly')
        allow(Organizations::Billing::ValueBasedPepm).to receive(:new).and_return(
          instance_double(
            Organizations::Billing::ValueBasedPepm,
            call: {
              total_value: 51.0,
              week_count: 13,
              teammate_count: 108,
              per_employee_week: 0.036,
              per_employee_month: 0.15,
              range_begin: Date.new(2026, 8, 18),
              range_end: Date.new(2026, 11, 16)
            }
          )
        )

        get organization_billing_path(organization)

        expect(response.body).to include('$0.15')
        expect(response.body).to include('With the 10% quarterly cadence discount, that brings the per employee per month price down to $0.14.')
        expect(response.body).to include('$0.00')
        expect(response.body).to include("OG is free until we've reached at least $0.50 per teammate in value")
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
        expect(response.body).to include('OG cost vs value')
        expect(response.body).to include('Priced from lookback')
        expect(response.body).to include('You pay')
        expect(response.body).to include('Locked on')
        expect(response.body).to include('No prior PEPM setpoint yet')
        expect(response.body).to include('Incomplete until')
        expect(response.body).not_to include('(incomplete)')
        expect(organization.billing_invoices.open_invoices.count).to eq(1)
        expect(response.body).not_to include('No open invoices yet')
        expect(response.body).not_to include('Create historical billing snapshots')
      end
    end
  end

  describe 'POST /organizations/:organization_id/billing/backfill_snapshots' do
    let(:can_manage_billing) { true }

    before do
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
            range_begin: Date.new(2026, 8, 1),
            range_end: Date.new(2026, 11, 14)
          }
        )
      )
    end

    it 'creates historical open invoices' do
      expect {
        post backfill_snapshots_organization_billing_path(organization)
      }.to change { organization.billing_invoices.open_invoices.count }.by(6)

      expect(response).to redirect_to(organization_billing_path(organization))
      follow_redirect!
      expect(response.body).to include('Created 6 historical billing snapshots')
      expect(response.body).not_to include('Create historical billing snapshots')
      expect(response.body).not_to include('No open invoices yet')
      expect(response.body).to include(
        organization_billing_invoice_path(organization, organization.billing_invoices.open_invoices.first)
      )
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

end
