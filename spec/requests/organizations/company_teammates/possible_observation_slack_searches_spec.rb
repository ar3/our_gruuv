# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Possible observation Slack searches", type: :request do
  include ActiveJob::TestHelper

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

      it "enqueues a search job and redirects to show" do
        expect {
          post organization_company_teammate_possible_observation_slack_searches_path(organization, subject),
               params: { possible_observation_slack_search: { window_days: 90 } }
        }.to change(PossibleObservationSlackSearch, :count).by(1)
          .and have_enqueued_job(PossibleObservationSlackSearchJob)

        search = PossibleObservationSlackSearch.order(:id).last
        expect(search.subject_company_teammate).to eq(subject)
        expect(search.creator_company_teammate).to eq(teammate)
        expect(search.search_status).to eq("pending")
        expect(response).to redirect_to(
          organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
        )
      end

      it "stores full results on ActiveStorage when the job runs" do
        stub_successful_slack_search

        perform_enqueued_jobs do
          post organization_company_teammate_possible_observation_slack_searches_path(organization, subject),
               params: { possible_observation_slack_search: { window_days: 90 } }
        end

        search = PossibleObservationSlackSearch.order(:id).last
        expect(search.reload.search_status).to eq("completed")
        expect(search.messages_count).to eq(1)
        expect(search.raw_results_file).to be_attached
        expect(search.raw_messages.first[:text]).to eq("Pat crushed the demo.")
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

    it "renders raw hits with permalinks and find-candidates action" do
      get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Pat did a great job on the launch.")
      expect(response.body).to include("Open in Slack")
      expect(response.body).to include("Showing 1 of 1 messages")
      expect(response.body).to include("Download")
      expect(response.body).to include("Consult OG to find potential OGOs")
    end
  end

  describe "GET download_raw_results" do
    let!(:search) do
      create(
        :possible_observation_slack_search,
        :completed,
        organization: organization,
        creator_company_teammate: teammate,
        subject_company_teammate: subject
      )
    end

    it "redirects to the attached raw results blob" do
      get download_raw_results_organization_company_teammate_possible_observation_slack_search_path(
        organization, subject, search
      )
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("rails/active_storage")
    end
  end

  describe "POST extract" do
    let!(:search) do
      create(
        :possible_observation_slack_search,
        :completed,
        organization: organization,
        creator_company_teammate: teammate,
        subject_company_teammate: subject,
        extraction_status: "ready"
      )
    end

    it "enqueues extraction and redirects" do
      expect {
        post extract_organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
      }.to have_enqueued_job(PossibleObservationSlackSearchExtractionJob)

      expect(search.reload.extraction_status).to eq("pending")
      expect(response).to redirect_to(
        organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
      )
    end
  end

  describe "review extracted candidates" do
    let!(:search) do
      create(
        :possible_observation_slack_search,
        :extracted,
        organization: organization,
        creator_company_teammate: teammate,
        subject_company_teammate: subject
      )
    end

    it "renders the review form" do
      get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Review candidate OGOs")
      expect(response.body).to include("Save candidates")
      expect(response.body).to include("Observer (speaker)")
      expect(response.body).to include(">Actions<")
      expect(response.body).to include("Include this candidate")
      expect(response.body).to include("data-slack-include")
      expect(response.body).to include("Kudos")
      expect(response.body).to include("Feedback")
      expect(response.body).not_to include("Quick note")
    end

    it "shows the rating and linked object name as text above the generated rationale" do
      assignment = create(:assignment, company: organization, title: "Own the launch")
      item = search.extraction_items.first.to_h.merge(
        "confidence" => 0.91,
        "target_is_subject" => true,
        "suggested_rateable_type" => "Assignment",
        "suggested_rateable_id" => assignment.id,
        "suggested_rateable_name" => assignment.title,
        "suggested_rating" => "strongly_agree",
        "association_reason" => "the message describes the assignment outcome",
        "rating_reason" => "the result exceeded expectations",
        "quote" => "OG is suggesting: Exceptional example of the Assignment, Own the launch."
      )
      search.replace_extraction_items!([item])

      get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("The OG Consultation AI Agent is suggesting:")
      expect(response.body).to include("OG is suggesting: Exceptional example of the Assignment, Own the launch.")
      expect(response.body).to include("Exceptional")
      expect(response.body).to include("Own the launch")
      expect(response.body).to include(
        organization_teammate_assignment_path(organization, subject, assignment.id)
      )
      expect(response.body).not_to include("text-bg-info")
    end

    it "saves include/kind updates" do
      item = search.extraction_items.first
      patch organization_company_teammate_possible_observation_slack_search_path(organization, subject, search),
            params: {
              items: {
                "0" => {
                  id: item[:id],
                  include: "0",
                  kind: "feedback",
                  quote: item[:quote],
                  summary: item[:summary],
                  short_quote: item[:short_quote],
                  full_quote: item[:full_quote],
                  speaker_label: item[:speaker_label],
                  recipient_label: item[:recipient_label],
                  responder_company_teammate_id: item[:responder_company_teammate_id],
                  subject_company_teammate_id: item[:subject_company_teammate_id],
                  channel_id: item[:channel_id],
                  ts: item[:ts],
                  permalink: item[:permalink],
                  slack_user_id: item[:slack_user_id]
                }
              }
            }

      expect(response).to redirect_to(
        organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
      )
      updated = search.reload.extraction_items.first
      expect(updated[:include]).to eq(false)
      expect(updated[:kind]).to eq("feedback")
    end

    context "when another OGO already points at the same Slack message" do
      before do
        trigger = create(
          :observation_trigger,
          trigger_source: "slack",
          trigger_type: "ogo_source_search",
          trigger_data: {
            "channel_id" => "C123",
            "message_ts" => "1710000000.000100"
          }
        )
        create(:observation, company: organization, observer: person, observation_trigger: trigger)
      end

      it "soft-warns without blocking review" do
        get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Already linked")
        expect(response.body).to include("Save candidates")
      end
    end
  end

  describe "GET search_status" do
    let!(:search) do
      create(
        :possible_observation_slack_search,
        organization: organization,
        creator_company_teammate: teammate,
        subject_company_teammate: subject,
        search_status: "processing"
      )
    end

    it "returns the established background-processing status payload" do
      get search_status_organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json["status"]).to eq("processing")
      expect(json).to include("elapsed_seconds", "slow", "stale", "updated_at")
      expect(json).to include("estimated_duration_seconds", "eta_confidence")
    end
  end

  describe "GET show while processing" do
    let!(:search) do
      create(
        :possible_observation_slack_search,
        organization: organization,
        creator_company_teammate: teammate,
        subject_company_teammate: subject,
        search_status: "processing"
      )
    end

    it "renders the waiting banner and skeleton placeholders" do
      get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Search is processing")
      expect(response.body).to include("og-consultation-status-poll")
      expect(response.body).to include("Last checked: just now")
      expect(response.body).to include("Estimating")
      expect(response.body).to include("placeholder-glow")
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
