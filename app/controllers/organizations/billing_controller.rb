# frozen_string_literal: true

class Organizations::BillingController < Organizations::OrganizationNamespaceBaseController
  before_action :set_billing_managers

  def show
    authorize organization, :view_billing?

    @can_manage_billing = policy(organization).manage_billing?
    return unless @can_manage_billing

    @billing_setting = OrganizationBillingSetting.for_organization!(organization)
    @value_metrics = Organizations::Billing::ValueBasedPepm.new(company).call
    @upcoming_pepm = discounted_pepm(@value_metrics[:per_employee_month], @billing_setting)

    ensure_locks_for_passed_calculations!

    @billing_periods = Organizations::Billing::PeriodViews.call(
      organization: organization,
      cadence: @billing_setting.cadence,
      live_pepm: @upcoming_pepm,
      first_due_on: @billing_setting.reload.next_payment_due_on
    )
    @display_pepm = @billing_periods.find(&:locked?)&.pepm || @upcoming_pepm
    @open_invoices = organization.billing_invoices.open_invoices
    @paid_invoices = organization.billing_invoices.paid_invoices
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

  def stub_pay
    authorize organization, :manage_billing?

    redirect_to organization_billing_path(organization),
                notice: "Online payment is coming soon. This Pay button is a placeholder for now."
  end

  private

  def set_billing_managers
    @billing_managers = organization.teammates
      .with_billing_management
      .where(last_terminated_at: nil)
      .includes(:person)
      .sort_by { |t| t.person.casual_name.to_s.downcase }
  end

  def discounted_pepm(base_monthly, setting)
    return nil if base_monthly.nil?

    discounted = base_monthly * (1.0 - setting.discount_rate)
    Organizations::Billing::RoundDownToHalfDollar.call(discounted)
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
end
