# frozen_string_literal: true

class Organizations::BillingInvoicesController < Organizations::OrganizationNamespaceBaseController
  before_action :set_invoice

  def show
    authorize organization, :manage_billing?
    assign_period_view
  end

  def stub_pay
    authorize organization, :manage_billing?

    unless @invoice.payable?
      redirect_to organization_billing_invoice_path(organization, @invoice),
                  alert: "This invoice cannot be paid in its current status."
      return
    end

    redirect_to organization_billing_invoice_path(organization, @invoice),
                notice: "Online payment is coming soon. This Pay button is a placeholder for now."
  end

  def update_status
    authorize organization, :manage_billing?

    unless impersonating?
      redirect_to organization_billing_invoice_path(organization, @invoice),
                  alert: "Manual status changes are only available while impersonating."
      return
    end

    new_status = params.require(:billing_invoice).permit(:status)[:status]
    unless BillingInvoice::MANUAL_STATUSES.include?(new_status)
      redirect_to organization_billing_invoice_path(organization, @invoice),
                  alert: "That status can only be set by payment automation."
      return
    end

    @invoice.apply_manual_status!(new_status)
    redirect_to organization_billing_invoice_path(organization, @invoice),
                notice: "Invoice status updated to #{@invoice.status_label}."
  end

  private

  def set_invoice
    @invoice = organization.billing_invoices.find(params[:id])
  end

  def assign_period_view
    prior_pepm = organization.billing_invoices
      .where("due_on < ?", @invoice.due_on)
      .order(due_on: :desc)
      .limit(1)
      .pick(:pepm)
      &.to_f
    @period_view = Organizations::Billing::PeriodViews::View.new(
      due_on: @invoice.due_on,
      calculation_on: @invoice.due_on - 1.week,
      locked?: true,
      pepm: @invoice.pepm.to_f,
      amount_due: @invoice.amount_due.to_f,
      prior_pepm: prior_pepm,
      value_delivered_total: @invoice.value_delivered_total&.to_f,
      teammate_count: @invoice.teammate_count,
      incomplete?: false,
      value_analysis: Organizations::Billing::ValueAnalysisTable.call(
        organization: organization,
        cadence: @invoice.cadence,
        period_due_on: @invoice.due_on
      )
    )
  end
end
