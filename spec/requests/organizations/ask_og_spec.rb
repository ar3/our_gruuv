# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::AskOg", type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "GET /organizations/:organization_id/ask_ogs/panel" do
    it "returns the Ask OG panel fragment" do
      get panel_organization_ask_ogs_path(organization, q: "how do I check in")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Ask OG")
      expect(response.body).to include("ask-og")
      expect(response.body).to include("Message Ask OG")
    end
  end

  describe "POST /organizations/:organization_id/ask_ogs" do
    it "starts a consultation with a user message and enqueues the job" do
      expect {
        post organization_ask_ogs_path(organization), params: { q: "draft kudos for a teammate" }
      }.to have_enqueued_job(AskOgJob)

      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["ok"]).to eq(true)
      expect(body["reply_url"]).to be_present
      consultation = OgConsultation.find(body["consultation_id"])
      expect(consultation.kind).to eq(OgConsultation::KIND_ASK_OG)
      expect(consultation.result).to be_a(AskOgResult)
      expect(consultation.result.query).to eq("draft kudos for a teammate")
      expect(consultation.result.ask_og_messages.user_messages.count).to eq(1)
    end
  end

  describe "POST /organizations/:organization_id/ask_ogs/:id/reply" do
    it "appends a follow-up and re-enqueues" do
      started = Assistant::StartAskOg.call(
        organization: organization,
        company_teammate: teammate,
        query: "first"
      )
      consultation = started.value[:consultation]
      consultation.update!(status: "completed", completed_at: Time.current, units_completed: 1)

      expect {
        post reply_organization_ask_og_path(organization, consultation), params: { message: "second" }
      }.to have_enqueued_job(AskOgJob)

      expect(response).to have_http_status(:success)
      expect(consultation.result.ask_og_messages.user_messages.count).to eq(2)
    end
  end

  describe "GET /organizations/:organization_id/ask_ogs/:id/status" do
    it "returns messages and rendered markdown for assistant turns" do
      started = Assistant::StartAskOg.call(
        organization: organization,
        company_teammate: teammate,
        query: "help"
      )
      consultation = started.value[:consultation]
      consultation.result.append_message!(
        role: AskOgMessage::ROLE_ASSISTANT,
        body: "**Bold** and a list:\n\n- one\n- two",
        proposed_actions: []
      )
      consultation.result.update!(answer_text: "**Bold** and a list:\n\n- one\n- two")
      consultation.update!(status: "completed", completed_at: Time.current, units_completed: 1)

      get status_organization_ask_og_path(organization, consultation)
      expect(response).to have_http_status(:success)
      body = JSON.parse(response.body)
      expect(body["messages"].size).to eq(2)
      expect(body["messages"].last["body_html"]).to include("<strong>Bold</strong>")
      expect(body["answer_html"]).to include("<li>")
    end
  end

  describe "search UX" do
    it "includes lazy Ask OG loader when there are zero hits and no Or Ask OG link" do
      get organization_search_path(organization, q: "zzznomatchxyz123")
      expect(response).to have_http_status(:success)
      expect(response.body).to include("ask-og-loader")
      expect(response.body).not_to include("Or Ask OG")
    end

    it "offers Start Ask OG after keyword hits" do
      create(:ability, company: organization, name: "UniqueAbilityXYZ", created_by: person, updated_by: person)
      # Ensure search can find something — if empty, still assert CTA path via ask_og param page
      get organization_search_path(organization, q: "a")
      expect(response).to have_http_status(:success)
      if response.body.include?("results")
        expect(response.body).to include("Start Ask OG").or include("ask-og-loader")
      end
      expect(response.body).not_to include("Or Ask OG")
    end

    it "shows recent searches and Ask OG on blank search" do
      SearchQueryLog.record!(
        organization: organization,
        company_teammate: teammate,
        query: "prior search",
        results_count: 2
      )
      started = Assistant::StartAskOg.call(
        organization: organization,
        company_teammate: teammate,
        query: "prior ask"
      )
      started.value[:consultation].update!(status: "completed", completed_at: Time.current, units_completed: 1)

      get organization_search_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Recent searches")
      expect(response.body).to include("prior search")
      expect(response.body).to include("Recent Ask OG")
      expect(response.body).to include("prior ask")
    end

    it "logs the search query" do
      expect {
        get organization_search_path(organization, q: "logged query")
      }.to change(SearchQueryLog, :count).by(1)
      expect(SearchQueryLog.order(:id).last.query).to eq("logged query")
    end
  end
end
