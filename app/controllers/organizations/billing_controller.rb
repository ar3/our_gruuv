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
    @display_pepm = @billing_periods.find(&:locked?)&.pepm || @upcoming_pepm
    @open_invoices = organization.billing_invoices.open_invoices
    @closed_invoices = organization.billing_invoices.closed_invoices
    @show_backfill_snapshots = show_backfill_snapshots?
  end

  def update_cadence
    authorize organization, :manage_billing?

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
