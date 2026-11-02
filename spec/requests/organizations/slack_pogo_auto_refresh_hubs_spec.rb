# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Slack pOGO auto-refresh hub", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  it "prompts Slack sign-in on the Consult hub when not connected" do
    get organization_possible_observation_consults_path(organization)
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Sign in to Slack to auto-refresh pOGOs")
    expect(response.body).to include("Source from a meeting transcript")
  end

  it "shows an auto-refresh switch when Slack is connected" do
    create(:teammate_identity, :slack_search, teammate: teammate)
    get organization_possible_observation_consults_path(organization)
    expect(response).to have_http_status(:success)
    expect(response.body).to include("slack-pogo-auto-refresh-hub")
    expect(response.body).to include("Keep my and my direct reports")
    expect(response.body).to include('role="switch"')
  end

  it "enables hub auto-refresh when Slack is connected" do
    create(:teammate_identity, :slack_search, teammate: teammate)
    report = create(:company_teammate, :assigned_employee, organization: organization)
    create(:employment_tenure, teammate: report, company: organization, manager_teammate: teammate, started_at: 1.year.ago, ended_at: nil)

    post organization_slack_pogo_auto_refresh_hub_path(organization)
    expect(response).to redirect_to(organization_possible_observation_consults_path(organization))
    expect(teammate.reload.slack_pogo_auto_refresh_hub_enabled).to eq(true)
    expect(SlackPogoAutoRefreshEnrollment.hub.where(runner_company_teammate: teammate).count).to eq(2)
  end
end
