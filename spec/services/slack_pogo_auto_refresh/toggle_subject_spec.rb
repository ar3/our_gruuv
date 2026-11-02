# frozen_string_literal: true

require "rails_helper"

RSpec.describe SlackPogoAutoRefresh::ToggleSubject do
  let(:organization) { create(:organization, :company) }
  let(:runner) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }

  before { create(:teammate_identity, :slack_search, teammate: runner) }

  it "opts a subject in and out manually" do
    result = described_class.call(runner: runner, subject: subject_teammate, enable: true)
    expect(result.ok?).to eq(true)
    expect(result.enabled?).to eq(true)
    expect(SlackPogoAutoRefreshEnrollment.find_by(runner_company_teammate: runner, subject_company_teammate: subject_teammate).source).to eq("manual")

    result = described_class.call(runner: runner, subject: subject_teammate, enable: false)
    expect(result.enabled?).to eq(false)
    expect(SlackPogoAutoRefreshEnrollment.find_by(runner_company_teammate: runner, subject_company_teammate: subject_teammate)).to be_nil
  end

  it "blocks turning off a hub-covered subject while hub is on" do
    create(:employment_tenure, teammate: subject_teammate, company: organization, manager_teammate: runner, started_at: 1.year.ago, ended_at: nil)
    SlackPogoAutoRefresh::SyncHub.enable(runner: runner)

    result = described_class.call(runner: runner, subject: subject_teammate, enable: false)
    expect(result.ok?).to eq(false)
    expect(result.locked_by_hub).to eq(true)
  end
end
