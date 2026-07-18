# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Slack OGO check-in consults", type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, :employment_manager, person: person, organization: organization) }
  let(:subject_person) { create(:person, full_name: "Pat Subject") }
  let(:subject) { create(:company_teammate, person: subject_person, organization: organization) }
  let(:assignment) { create(:assignment, company: organization, title: "Own the launch") }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: subject, company: organization, manager_teammate: teammate, started_at: 1.year.ago, ended_at: nil)
    subject.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
    create(:teammate_identity, :slack_search, teammate: teammate)
  end

  it "starts a fresh consult from the check-in endpoint" do
    expect {
      post organization_teammate_slack_ogo_check_in_consult_path(organization, subject),
           params: { mode: "fresh", rateable_type: "Assignment", rateable_id: assignment.id },
           as: :json
    }.to change(PossibleObservationSlackSearch, :count).by(1)
      .and have_enqueued_job(PossibleObservationSlackSearchJob)

    expect(response).to have_http_status(:success)
    json = response.parsed_body
    expect(json["ok"]).to eq(true)
    expect(json["phase"]).to eq("searching")
    expect(json["polling"]).to eq(true)
  end

  it "returns idle when there is no recent consultation" do
    get organization_teammate_slack_ogo_check_in_consult_path(organization, subject),
        params: { rateable_type: "Assignment", rateable_id: assignment.id },
        as: :json

    expect(response).to have_http_status(:success)
    expect(response.parsed_body["phase"]).to eq("idle")
  end

  it "renders Consult OG on the assignment check-in page" do
    get organization_teammate_assignment_path(organization, subject, assignment)
    expect(response).to have_http_status(:success)
    expect(response.body).to include("Consult OG for evidence")
    expect(response.body).to include("Get evidence manually")
    expect(response.body).to include("check-in-slack-ogo-consult")
  end
end
