# frozen_string_literal: true

class Organizations::BillingInvoicesController < Organizations::OrganizationNamespaceBaseController
  before_action :set_invoice, only: %i[show stub_pay update_status]

  def show
    authorize organization, :manage_billing?
    assign_period_view_from_invoice!
    assign_pepm_explanation!
  end

  def upcoming
    authorize organization, :manage_billing?

    due_on = Date.iso8601(params.require(:due_on))
    existing = organization.billing_invoices.find_by(due_on: due_on)
    if existing
      redirect_to organization_billing_invoice_path(organization, existing)
      return
    end

    assign_period_view_for_upcoming!(due_on)
    assign_pepm_explanation!
    render :upcoming
  rescue ArgumentError
    redirect_to organization_billing_path(organization), alert: "That upcoming invoice date is invalid."
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

  def assign_period_view_from_invoice!
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

  def assign_period_view_for_upcoming!(due_on)
    @billing_setting = OrganizationBillingSetting.for_organization!(organization)
    @value_metrics = Organizations::Billing::ValueBasedPepm.new(company).call
    discounted = apply_cadence_discount(@value_metrics[:per_employee_month], @billing_setting)
    live_pepm = floored_pepm(discounted)
    live_amount = Organizations::Billing::AmountDue.call(
      pepm: live_pepm.to_f,
      teammate_count: @value_metrics[:teammate_count].to_i,
      value_delivered: @value_metrics[:total_value].to_f,
      months: @billing_setting.months_in_period
    )
    prior_pepm = organization.billing_invoices
      .where("due_on < ?", due_on)
      .order(due_on: :desc)
      .limit(1)
      .pick(:pepm)
      &.to_f

    @due_on = due_on
    @period_starts_on = due_on
    @period_ends_on = Organizations::Billing::NextDueDate.call(
      cadence: @billing_setting.cadence,
      from: due_on + 1.day
    ) - 1.day
    @period_view = Organizations::Billing::PeriodViews::View.new(
      due_on: due_on,
      calculation_on: due_on - 1.week,
      locked?: false,
      pepm: live_pepm,
      amount_due: live_amount,
      prior_pepm: prior_pepm,
      value_delivered_total: @value_metrics[:total_value].to_f,
      teammate_count: @value_metrics[:teammate_count].to_i,
      incomplete?: true,
      value_analysis: Organizations::Billing::ValueAnalysisTable.call(
        organization: organization,
        cadence: @billing_setting.cadence,
        period_due_on: due_on
      )
    )
  end

  def assign_pepm_explanation!
    @billing_setting ||= OrganizationBillingSetting.for_organization!(organization)
    @value_metrics ||= Organizations::Billing::ValueBasedPepm.new(company).call
    base = @value_metrics[:per_employee_month]
    @discounted_pepm_before_floor = apply_cadence_discount(base, @billing_setting)
    @display_pepm = floored_pepm(@discounted_pepm_before_floor)
  end

  def apply_cadence_discount(base_monthly, setting)
    return nil if base_monthly.nil?

    (base_monthly.to_f * (1.0 - setting.discount_rate)).round(2)
  end

  def floored_pepm(discounted_monthly)
    return nil if discounted_monthly.nil?

    Organizations::Billing::RoundDownToHalfDollar.call(discounted_monthly)
  end
end
