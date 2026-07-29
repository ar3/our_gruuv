# frozen_string_literal: true

require "rails_helper"

RSpec.describe PossibleObservationSlackSearches::BulkDirectReportsStarter do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:direct) { create(:company_teammate, :assigned_employee, organization: organization) }

  before do
    create(:employment_tenure, teammate: direct, company: organization, manager_teammate: manager, started_at: 1.year.ago, ended_at: nil)
    create(:teammate_identity, :slack_search, teammate: manager)
  end

  it "starts a 30-day Sonnet auto-extract search for each direct report" do
    expect do
      result = described_class.call(organization: organization, manager: manager)
      expect(result.ok?).to be(true)
      expect(result.started_count).to eq(1)
    end.to change(PossibleObservationSlackSearch, :count).by(1)
      .and have_enqueued_job(PossibleObservationSlackSearchJob)

    search = PossibleObservationSlackSearch.last
    expect(search.window_days).to eq(30)
    expect(search.auto_extract_after_search).to be(true)
    expect(search.auto_extract_model_id).to eq(Llm::SlackMomentsExtractor.stronger_model_id)
    expect(search.subject_company_teammate).to eq(direct)
    expect(search.creator_company_teammate).to eq(manager)
  end

  it "returns needs_slack_oauth when the manager has no Slack search identity" do
    TeammateIdentity.where(company_teammate: manager).delete_all
    result = described_class.call(organization: organization, manager: manager)
    expect(result.ok?).to be(false)
    expect(result.needs_slack_oauth).to be(true)
  end

  it "returns an error when the manager has no direct reports" do
    EmploymentTenure.where(manager_teammate: manager).delete_all
    result = described_class.call(organization: organization, manager: manager)
    expect(result.ok?).to be(false)
    expect(result.error).to include("no direct reports")
  end
end
