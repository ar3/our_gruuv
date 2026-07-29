# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Direct reports Slack OGO consults", type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:manager) { create(:company_teammate, :employment_manager, person: person, organization: organization) }
  let(:direct) { create(:company_teammate, :assigned_employee, organization: organization) }

  before do
    create(:employment_tenure, teammate: manager, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager.update!(first_employed_at: 1.year.ago)
    create(
      :employment_tenure,
      teammate: direct,
      company: organization,
      manager_teammate: manager,
      started_at: 1.year.ago,
      ended_at: nil
    )
    direct.update!(first_employed_at: 1.year.ago)
    create(:teammate_identity, :slack_search, teammate: manager)
    sign_in_as_teammate_for_request(person, organization)
  end

  it "starts per-direct Slack searches and redirects to the consults hub" do
    expect do
      post organization_direct_reports_slack_ogo_consults_path(organization)
    end.to change(PossibleObservationSlackSearch, :count).by(1)
      .and have_enqueued_job(PossibleObservationSlackSearchJob)

    search = PossibleObservationSlackSearch.last
    expect(search.window_days).to eq(30)
    expect(search.auto_extract_model_id).to eq(Llm::SlackMomentsExtractor.stronger_model_id)
    expect(response).to redirect_to(organization_possible_observation_consults_path(organization))
    expect(flash[:notice]).to include("may take a while")
  end
end
