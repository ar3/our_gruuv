# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Teammate OGOs page", type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/company_teammates/:id/ogos" do
    it "allows the teammate to view their own OGOs page" do
      get ogos_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(person.casual_name)
      expect(response.body).to include("s OGOs")
      expect(response.body).to include("About #{person.casual_name}")
      expect(response.body).to include("OGO health (last 30 days)")
    end

    it "shows notes-only self CTA, header add-any-teammate link, and hides self kudos/feedback" do
      get ogos_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("Add an OGO about any teammate")
      expect(response.body).to include(select_type_organization_observations_path(organization))
      expect(response.body).to include("Add notes about me")
      expect(response.body).to include("Request feedback about me")
      expect(response.body).to include(new_organization_feedback_request_path(organization, subject_of_feedback_teammate_id: teammate.id))
      expect(response.body).to include("Why keep notes about yourself?")
      expect(response.body).to include(new_quick_note_organization_observations_path(organization))
      expect(response.body).to include("observee_ids")
      expect(response.body).to include(teammate.id.to_s)
      expect(response.body).not_to include("Add Self-Kudos")
      expect(response.body).not_to include("Add Self-Feedback")
      expect(response.body).not_to include("Add Kudos about #{person.casual_name}")
      expect(response.body).not_to include("Add Constructive Feedback about #{person.casual_name}")
    end

    context "when viewing another teammate's OGOs page" do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }

      before do
        create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil, manager_teammate: teammate)
        other_teammate.update!(first_employed_at: 1.year.ago)
      end

      it "labels CTAs with the teammate's name and omits the self-observation callout" do
        get ogos_organization_company_teammate_path(organization, other_teammate)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Add an OGO about any teammate")
        expect(response.body).to include("Add Kudos about #{other_person.casual_name}")
        expect(response.body).to include("Add Constructive Feedback about #{other_person.casual_name}")
        expect(response.body).to include("Add Note about #{other_person.casual_name}")
        expect(response.body).to include("Request feedback about #{other_person.casual_name}")
        expect(response.body).to include(new_organization_feedback_request_path(organization, subject_of_feedback_teammate_id: other_teammate.id))
        expect(response.body).not_to include("Why keep notes about yourself?")
        expect(response.body).not_to include("Add notes about me")
      end
    end


    it "includes the Source from Slack tab on the OGOs page" do
      get ogos_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("Source from Slack")
      expect(response.body).to include("/ogos/source_from_slack")
    end
  end

  describe "GET /organizations/:organization_id/company_teammates/:id/ogos/from" do
    it "renders the from tab" do
      get ogos_from_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("From #{person.casual_name}")
    end
  end

  describe "GET /organizations/:organization_id/company_teammates/:id/ogos/source_from_slack" do
    it "renders the Source from Slack Beta tab with page help" do
      get ogos_source_from_slack_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Source from Slack")
      expect(response.body).to include("Beta")
      expect(response.body).to include("sourceFromSlackPageHelp")
      expect(response.body).to include("missed reinforcement is partly on you")
      expect(response.body).to include("Slack moments about #{person.casual_name}")
      expect(response.body).to include("Search runs")
      expect(response.body).not_to include("OGO health (last 30 days)")
    end

    it "renders the Search runs index with page help" do
      get ogos_slack_search_runs_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Search runs about #{person.casual_name}")
      expect(response.body).to include("slackSearchRunsPageHelp")
    end

    it "renders a search run show with open pOGOs using the shared moment row" do
      search = create(
        :possible_observation_slack_search,
        organization: organization,
        subject_company_teammate: teammate,
        creator_company_teammate: teammate
      )
      create(
        :slack_possible_observation,
        organization: organization,
        subject_company_teammate: teammate,
        discoverer_company_teammate_ids: [teammate.id],
        possible_observation_slack_search: search,
        discovery_search_ids: [search.id],
        payload: {
          "summary" => "Run-scoped praise",
          "quote" => "Nice ship from this run",
          "confidence" => 0.88
        }
      )

      get ogos_slack_search_run_organization_company_teammate_path(organization, teammate, search)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Open pOGOs from this run")
      expect(response.body).to include("Run-scoped praise")
      expect(response.body).to include("Nice ship from this run")
      expect(response.body).to include("context-callout")
      expect(response.body).to include("Promote to OGO")
      expect(response.body).to include("Dismiss: this is not OGO-worthy")
    end

    it "prompts the viewer to connect Slack (search) when not connected" do
      get ogos_source_from_slack_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("Connect Slack (search)")
      expect(response.body).to include("/slack_search/oauth/authorize")
    end

    context "when the viewer has a Slack search identity" do
      before { create(:teammate_identity, :slack_search, teammate: teammate) }

      it "shows connected status with reconnect, disconnect, and search form" do
        get ogos_source_from_slack_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include("Slack (search) is connected")
        expect(response.body).to include("Reconnect")
        expect(response.body).to include("Disconnect")
        expect(response.body).to include("Run a new search")
      end
    end

    it "shows the per-subject auto-refresh control when Slack is connected" do
      create(:teammate_identity, :slack_search, teammate: teammate)
      get ogos_source_from_slack_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include("auto-refresh every 14 days")
      expect(response.body).to include("Keep #{person.casual_name}")
    end

    it "lists durable Slack moments the viewer can see and supports dismiss" do
      moment = create(
        :slack_possible_observation,
        organization: organization,
        subject_company_teammate: teammate,
        discoverer_company_teammate_ids: [teammate.id],
        payload: {
          "summary" => "Launch praise worth capturing",
          "quote" => "Pat crushed the timeline",
          "confidence" => 0.92,
          "channel_name" => "general",
          "permalink" => "https://example.slack.com/p1"
        }
      )
      private_other = create(
        :slack_possible_observation,
        :private_or_dm,
        organization: organization,
        subject_company_teammate: teammate,
        discoverer_company_teammate_ids: [create(:company_teammate, organization: organization).id],
        payload: { "summary" => "Secret DM praise", "confidence" => 0.8 }
      )

      get ogos_source_from_slack_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Launch praise worth capturing")
      expect(response.body).to include("Pat crushed the timeline")
      expect(response.body).to include("context-callout")
      expect(response.body).to include("Dismiss: this is not OGO-worthy")
      expect(response.body).to include("Promote to OGO")
      expect(response.body).not_to include("Secret DM praise")

      post dismiss_organization_company_teammate_slack_possible_observation_path(organization, teammate, moment)
      expect(response).to redirect_to(ogos_source_from_slack_organization_company_teammate_path(organization, teammate))
      expect(moment.reload).to be_dismissed

      get ogos_source_from_slack_organization_company_teammate_path(organization, teammate)
      expect(response.body).not_to include("Launch praise worth capturing")
      expect(private_other.reload).not_to be_dismissed
    end

    it "promotes a Slack moment to a draft OGO and keeps it on the list" do
      moment = create(
        :slack_possible_observation,
        organization: organization,
        subject_company_teammate: teammate,
        discoverer_company_teammate_ids: [teammate.id],
        channel_id: "Cpromote",
        message_ts: "1710000000.001111",
        payload: {
          "summary" => "Promote me please",
          "quote" => "Great work in public",
          "confidence" => 0.91,
          "kind" => "kudos",
          "responder_company_teammate_id" => teammate.id
        }
      )

      expect {
        post promote_organization_company_teammate_slack_possible_observation_path(organization, teammate, moment)
      }.to change(Observation, :count).by(1)

      expect(response).to redirect_to(ogos_source_from_slack_organization_company_teammate_path(organization, teammate))
      follow_redirect!
      expect(response.body).to include("Promote me please")
      expect(response.body).to include("Draft OGO — needs publishing")
      expect(response.body).to include("Open draft / Finish publishing")
      expect(response.body).not_to include(">Promote to OGO<")
    end
  end

  describe "GET /organizations/:organization_id/company_teammates/:id/ogos/feedback_requests" do
    it "renders the feedback requests inbox with three sections" do
      other = create(:company_teammate, organization: organization)
      create(:employment_tenure, teammate: other, company: organization, started_at: 1.year.ago, ended_at: nil)
      create(:feedback_request, :ready_open_link,
             company: organization,
             requestor_teammate: teammate,
             subject_of_feedback_teammate: other,
             subject_line: "Ship retro feedback")

      get ogos_feedback_requests_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("360° Feedback Requests")
      expect(response.body).to include("Waiting on #{person.casual_name}")
      expect(response.body).to include("About #{person.casual_name}")
      expect(response.body).to include("#{person.casual_name} asked for others")
      expect(response.body).not_to include("#{person.casual_name} asked of others")
      expect(response.body).to include("Show closed")
      expect(response.body).to include("archived")
      expect(response.body).to include("Ship retro feedback")
      expect(response.body).to include(">Request<")
      expect(response.body).not_to include(">Focus<")
      expect(response.body).to match(/data-bs-toggle=["']popover["']/)
    end

    it "supports the /me/ teammate alias" do
      get ogos_feedback_requests_organization_company_teammate_path(organization, "me")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Waiting on #{person.casual_name}")
      expect(response.body).to include("360° Feedback Requests")
    end

    context "with open and closed involvement" do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }
      let(:requestor_person) { create(:person) }
      let(:requestor) { create(:company_teammate, person: requestor_person, organization: organization) }

      let!(:waiting_request) do
        create(:feedback_request,
               company: organization,
               requestor_teammate: requestor,
               subject_of_feedback_teammate: other_teammate).tap do |fr|
          fr.feedback_request_responders.create!(teammate: teammate)
        end
      end

      let!(:about_request) do
        create(:feedback_request,
               company: organization,
               requestor_teammate: requestor,
               subject_of_feedback_teammate: teammate)
      end

      let!(:self_request) do
        create(:feedback_request,
               company: organization,
               requestor_teammate: teammate,
               subject_of_feedback_teammate: teammate)
      end

      let!(:for_others_request) do
        create(:feedback_request,
               company: organization,
               requestor_teammate: teammate,
               subject_of_feedback_teammate: other_teammate)
      end

      let!(:archived_about) do
        create(:feedback_request, :archived,
               company: organization,
               requestor_teammate: requestor,
               subject_of_feedback_teammate: teammate)
      end

      before do
        create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        create(:employment_tenure, teammate: requestor, company: organization, started_at: 1.year.ago, ended_at: nil)
      end

      it "shows open requests in the matching sections and hides archived by default" do
        get ogos_feedback_requests_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include(other_teammate.person.display_name)
        expect(response.body).to include(requestor.person.display_name)
        expect(response.body).to include(waiting_request.subject_of_feedback_teammate.person.display_name)
        expect(response.body).not_to include("Archived")
      end

      it "includes archived requests when show_closed=1" do
        get ogos_feedback_requests_organization_company_teammate_path(organization, teammate, show_closed: "1")
        expect(response.body).to include("Show open only")
        expect(response.body).to include("Archived")
      end
    end

    context "when the viewer owes a response about the subject" do
      let(:requestor_person) { create(:person) }
      let(:requestor) { create(:company_teammate, person: requestor_person, organization: organization) }
      let!(:feedback_request) do
        create(:feedback_request, company: organization, requestor_teammate: requestor, subject_of_feedback_teammate: teammate)
      end

      before do
        create(:employment_tenure, teammate: requestor, company: organization, started_at: 1.year.ago, ended_at: nil)
        feedback_request.responders << teammate
      end

      it "shows an open respondent banner on the feedback requests tab only" do
        get ogos_organization_company_teammate_path(organization, teammate)
        expect(response.body).not_to include("You have open feedback requests to answer")

        get ogos_feedback_requests_organization_company_teammate_path(organization, teammate)
        expect(response.body).to include("You have open feedback requests to answer")
        expect(response.body).to include("Respond")
      end
    end
  end

  describe "authorization" do
    let(:other_person) { create(:person) }
    let(:other_teammate) { create(:company_teammate, person: other_person, organization: organization) }

    before do
      create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
      other_teammate.update!(first_employed_at: 1.year.ago)
      sign_in_as_teammate_for_request(other_person, organization)
    end

    it "denies access when viewing another teammate without permission" do
      get ogos_organization_company_teammate_path(organization, teammate)
      expect(response).to have_http_status(:redirect)
    end
  end
end
