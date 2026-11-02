# frozen_string_literal: true

require "rails_helper"

RSpec.describe SlackPogoAutoRefresh::SyncHub do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:report) { create(:company_teammate, :assigned_employee, organization: organization) }

  before do
    create(:employment_tenure, teammate: report, company: organization, manager_teammate: manager, started_at: 1.year.ago, ended_at: nil)
    create(:teammate_identity, :slack_search, teammate: manager)
  end

  it "enables hub for self + directs and locks them as hub enrollments" do
    result = described_class.enable(runner: manager)
    expect(result.ok?).to eq(true)
    expect(manager.reload.slack_pogo_auto_refresh_hub_enabled).to eq(true)

    subjects = SlackPogoAutoRefreshEnrollment.where(runner_company_teammate: manager).map(&:subject_company_teammate_id)
    expect(subjects).to contain_exactly(manager.id, report.id)
    expect(SlackPogoAutoRefreshEnrollment.hub.where(runner_company_teammate: manager).count).to eq(2)
  end

  it "disabling hub removes hub enrollments but leaves manual ones" do
    described_class.enable(runner: manager)
    other = create(:company_teammate, :assigned_employee, organization: organization)
    create(
      :slack_pogo_auto_refresh_enrollment,
      organization: organization,
      runner_company_teammate: manager,
      subject_company_teammate: other,
      source: "manual"
    )

    described_class.disable(runner: manager)
    expect(manager.reload.slack_pogo_auto_refresh_hub_enabled).to eq(false)
    expect(SlackPogoAutoRefreshEnrollment.hub.where(runner_company_teammate: manager)).to be_empty
    expect(SlackPogoAutoRefreshEnrollment.manual.where(runner_company_teammate: manager).pluck(:subject_company_teammate_id)).to eq([other.id])
  end

  it "reconciles DR churn while hub is on" do
    described_class.enable(runner: manager)
    new_report = create(:company_teammate, :assigned_employee, organization: organization)
    create(:employment_tenure, teammate: new_report, company: organization, manager_teammate: manager, started_at: 1.day.ago, ended_at: nil)
    EmploymentTenure.where(teammate_id: report.id, manager_teammate_id: manager.id).update_all(ended_at: Time.current)

    described_class.reconcile_if_enabled(runner: manager.reload)
    subjects = SlackPogoAutoRefreshEnrollment.hub.where(runner_company_teammate: manager).pluck(:subject_company_teammate_id)
    expect(subjects).to contain_exactly(manager.id, new_report.id)
  end
end
