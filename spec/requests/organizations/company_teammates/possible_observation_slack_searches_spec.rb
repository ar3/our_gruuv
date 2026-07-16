# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Possible observation Slack searches", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, :employment_manager, person: person, organization: organization) }
  let(:subject_person) { create(:person, full_name: "Pat Subject") }
  let(:subject) { create(:company_teammate, person: subject_person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: subject, company: organization, manager_teammate: teammate, started_at: 1.year.ago, ended_at: nil)
    subject.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  def stub_successful_slack_search
    body = {
      "ok" => true,
      "messages" => {
        "total" => 1,
        "matches" => [
          {
            "iid" => "1",
            "team" => "T1",
            "channel" => { "id" => "C1", "name" => "general" },
            "user" => "U1",
            "username" => "alex",
            "ts" => "1710000000.000100",
            "text" => "Pat crushed the demo.",
            "permalink" => "https://example.slack.com/archives/C1/p1"
          }
        ],
        "paging" => { "count" => 1, "total" => 1, "page" => 1, "pages" => 1 }
      }
    }
    response = double(body: double(to_s: body.to_json))
    allow(HTTP).to receive(:auth).and_return(double(get: response))
  end

  describe "POST create" do
    context "when Slack (search) is connected" do
      before { create(:teammate_identity, :slack_search, teammate: teammate) }

      it "creates a search about the subject, runs Slack API, and redirects to show" do
        stub_successful_slack_search

        expect {
          post organization_company_teammate_possible_observation_slack_searches_path(organization, subject),
               params: { possible_observation_slack_search: { window_days: 90 } }
        }.to change(PossibleObservationSlackSearch, :count).by(1)

        search = PossibleObservationSlackSearch.order(:id).last
        expect(search.subject_company_teammate).to eq(subject)
        expect(search.creator_company_teammate).to eq(teammate)
        expect(search.search_status).to eq("completed")
        expect(response).to redirect_to(
          organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
        )
      end
    end

    context "when Slack (search) is not connected" do
      it "does not create a search" do
        expect {
          post organization_company_teammate_possible_observation_slack_searches_path(organization, subject),
               params: { possible_observation_slack_search: { window_days: 90 } }
        }.not_to change(PossibleObservationSlackSearch, :count)
      end
    end
  end

  describe "GET show" do
    let!(:search) do
      create(
        :possible_observation_slack_search,
        :completed,
        organization: organization,
        creator_company_teammate: teammate,
        subject_company_teammate: subject
      )
    end

    it "renders raw hits with permalinks" do
      get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pat did a great job on the launch.")
      expect(response.body).to include("Open in Slack")
      expect(response.body).to include("example.slack.com")
    end
  end

  describe "Source tab" do
    before { create(:teammate_identity, :slack_search, teammate: teammate) }

    let!(:prior_search) do
      create(
        :possible_observation_slack_search,
        :completed,
        organization: organization,
        creator_company_teammate: teammate,
        subject_company_teammate: subject,
        display_name: "Prior search about Pat"
      )
    end

    it "lists prior searches and the run form for the subject" do
      get ogos_source_from_slack_organization_company_teammate_path(organization, subject)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Run a new search")
      expect(response.body).to include("Prior search about Pat")
      expect(response.body).to include("Open")
    end
  end
end
