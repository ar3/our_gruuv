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
    expect(response.body).to include("check-in-get-evidence-manually")
    expect(response.body).to include("check-in-slack-ogo-consult")
    expect(response.body).to include("Promote or dismiss these on Slack moments")
    expect(response.body).not_to include("stronger model")
  end

  it "returns shared moment-row HTML for object matches without promote/dismiss actions" do
    create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject,
      discoverer_company_teammate_ids: [teammate.id],
      message_ts: 2.days.ago.to_f.to_s,
      payload: {
        "confidence" => 0.92,
        "summary" => "Check-in evidence summary",
        "quote" => "Pat crushed the demo",
        "suggested_rateable_type" => "Assignment",
        "suggested_rateable_id" => assignment.id,
        "suggested_rateable_name" => assignment.title,
        "suggested_rating" => "agree",
        "permalink" => "https://example.slack.com/archives/C1/p1"
      }
    )

    get organization_teammate_slack_ogo_check_in_consult_path(organization, subject),
        params: { rateable_type: "Assignment", rateable_id: assignment.id },
        as: :json

    expect(response).to have_http_status(:success)
    match = response.parsed_body["object_matches"].first
    expect(match["html"]).to include("Check-in evidence summary")
    expect(match["html"]).to include("Open in Slack")
    expect(match["html"]).to include("bg-primary")
    expect(match["html"]).not_to include("Promote to OGO")
    expect(response.parsed_body["full_results_url"]).to include("source_from_slack")
  end
end

