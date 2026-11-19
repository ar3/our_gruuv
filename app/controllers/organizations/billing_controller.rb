# frozen_string_literal: true

class Organizations::BillingController < Organizations::OrganizationNamespaceBaseController
  before_action :set_billing_managers

  def show
    authorize organization, :view_billing?

    @can_manage_billing = policy(organization).manage_billing?
    return unless @can_manage_billing

    @billing_setting = OrganizationBillingSetting.for_organization!(organization)
    @value_metrics = Organizations::Billing::ValueBasedPepm.new(company).call
    @discounted_pepm_before_floor = apply_cadence_discount(
      @value_metrics[:per_employee_month],
      @billing_setting
    )
    @upcoming_pepm = floored_pepm(@discounted_pepm_before_floor)

    ensure_locks_for_passed_calculations!

    @billing_periods = Organizations::Billing::PeriodViews.call(
      organization: organization,
      cadence: @billing_setting.cadence,
      live_pepm: @upcoming_pepm,
      live_metrics: @value_metrics,
      months_in_period: @billing_setting.months_in_period,
      first_due_on: @billing_setting.reload.next_payment_due_on
    )
    @focus_period = @billing_periods.find { |period| period.value_analysis.present? } || @billing_periods.first
    @display_pepm = @billing_periods.find(&:locked?)&.pepm || @upcoming_pepm
    assign_clarity_outcomes_for_focus_period!
    @invoice_table_rows = build_invoice_table_rows
    @show_backfill_snapshots = show_backfill_snapshots?
  end

  def update_cadence
    authorize organization, :manage_billing?

    unless impersonating?
      redirect_to organization_billing_path(organization),
                  alert: "Billing cadence can only be changed while impersonating."
      return
    end

    setting = OrganizationBillingSetting.for_organization!(organization)
    cadence = params.require(:organization_billing_setting).permit(:cadence)[:cadence]

    if OrganizationBillingSetting::CADENCES.include?(cadence)
      setting.update!(
        cadence: cadence,
        next_payment_due_on: Organizations::Billing::NextDueDate.call(cadence: cadence)
      )
      redirect_to organization_billing_path(organization), notice: "Billing cadence updated."
    else
      redirect_to organization_billing_path(organization), alert: "Choose a valid billing cadence."
    end
  end

  def backfill_snapshots
    authorize organization, :manage_billing?

    result = Organizations::Billing::BackfillSnapshots.call(organization: organization)

    if result.skipped_reason == "already_has_invoices"
      redirect_to organization_billing_path(organization),
                  alert: "Historical snapshots already exist."
    elsif result.created_count.zero?
      redirect_to organization_billing_path(organization),
                  alert: "No past billing periods were available to snapshot."
    else
      redirect_to organization_billing_path(organization),
                  notice: "Created #{result.created_count} historical billing #{'snapshot'.pluralize(result.created_count)}."
    end
  end

  private

  def set_billing_managers
    @billing_managers = organization.teammates
      .with_billing_management
      .where(last_terminated_at: nil)
      .includes(:person)
      .sort_by { |t| t.person.casual_name.to_s.downcase }
  end

  InvoiceTableRow = Struct.new(
    :status,
    :due_on,
    :period_starts_on,
    :period_ends_on,
    :teammate_count,
    :value_pepm,
    :pepm,
    :amount_due,
    :invoice,
    keyword_init: true
  )

  def build_invoice_table_rows
    invoice_rows = organization.billing_invoices.order(due_on: :desc).map do |invoice|
      InvoiceTableRow.new(
        status: billing_list_status_for_invoice(invoice),
        due_on: invoice.due_on,
        period_starts_on: invoice.period_starts_on,
        period_ends_on: invoice.period_ends_on,
        teammate_count: invoice.teammate_count,
        value_pepm: invoice.og_cost_pepm,
        pepm: invoice.pepm.to_f,
        amount_due: invoice.amount_due.to_f,
        invoice: invoice
      )
    end

    invoiced_dues = invoice_rows.map(&:due_on)
    live_value_pepm = @value_metrics[:per_employee_month]
    future_rows = @billing_periods.reject(&:locked?).first(2).filter_map do |period|
      next if invoiced_dues.include?(period.due_on)

      range = period_date_range_for(period.due_on)
      lookback_pepm = period.value_analysis&.totals&.dig(:lookback)&.pepm
      InvoiceTableRow.new(
        status: "Future",
        due_on: period.due_on,
        period_starts_on: range.begin,
        period_ends_on: range.end,
        teammate_count: period.teammate_count,
        value_pepm: lookback_pepm || live_value_pepm,
        pepm: period.pepm.to_f,
        amount_due: period.amount_due.to_f,
        invoice: nil
      )
    end

    (invoice_rows + future_rows).sort_by(&:due_on).reverse
  end

  def billing_list_status_for_invoice(invoice)
    case invoice.status
    when "open", "processing", "failed" then "Due"
    when "paid" then "Paid"
    when "waived" then "Waived"
    else invoice.status_label
    end
  end

  def period_date_range_for(due_on)
    ends_on = Organizations::Billing::NextDueDate.call(
      cadence: @billing_setting.cadence,
      from: due_on + 1.day
    ) - 1.day
    due_on.to_date..ends_on.to_date
  end

  def assign_clarity_outcomes_for_focus_period!
    @clarity_outcome_rows = []
    @clarity_period_label = nil
    return if @focus_period.blank?

    column = @focus_period.value_analysis&.column_for(:current)
    return if column.blank? || column.starts_on.blank? || column.ends_on.blank?

    range =
      if column.in_progress?
        column.starts_on..Date.current
      else
        column.starts_on..column.ends_on
      end

    @clarity_outcome_rows = Organizations::Billing::ValueDrivers.new(company).breakdown(range)
    @clarity_period_label =
      if column.in_progress?
        "This billing period so far: #{l(column.starts_on, format: :long)} – #{l(Date.current, format: :long)}"
      else
        "This billing period: #{l(column.starts_on, format: :long)} – #{l(column.ends_on, format: :long)}"
      end
  end

  # Cadence discount only (nearest cent). Flooring to $0.50 is separate.
  def apply_cadence_discount(base_monthly, setting)
    return nil if base_monthly.nil?

    (base_monthly.to_f * (1.0 - setting.discount_rate)).round(2)
  end

  def floored_pepm(discounted_monthly)
    return nil if discounted_monthly.nil?

    Organizations::Billing::RoundDownToHalfDollar.call(discounted_monthly)
  end

  def ensure_locks_for_passed_calculations!
    periods = Organizations::Billing::UpcomingPeriods.call(
      cadence: @billing_setting.cadence,
      count: 3,
      first_due_on: @billing_setting.next_payment_due_on
    )
    periods.each do |period|
      next unless period.calculation_passed?

      Organizations::Billing::LockPepm.call(
        organization: organization,
        due_on: period.due_on,
        as_of: Date.current
      )
    end
  end

  def show_backfill_snapshots?
    organization.billing_invoices.none? &&
      @value_metrics[:total_value].to_f.positive?
  end
end
