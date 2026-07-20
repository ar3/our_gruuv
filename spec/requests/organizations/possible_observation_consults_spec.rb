# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Possible observation consults", type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, :employment_manager, person: person, organization: organization) }
  let(:other_person) { create(:person, full_name: "Pat Subject", preferred_name: "Pat") }
  let(:other) { create(:company_teammate, person: other_person, organization: organization) }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: other, company: organization, started_at: 1.year.ago, ended_at: nil)
    other.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe "POST create" do
    it "saves paste content and suggests teammates by name" do
      expect do
        post organization_possible_observation_consults_path(organization),
             params: {
               possible_observation_consult: {
                 display_name: "Weekly sync",
                 source_text: "Pat did a great job shipping the launch this week."
               }
             }
      end.to change(PossibleObservationConsult, :count).by(1)

      consult = PossibleObservationConsult.last
      expect(response).to redirect_to(organization_possible_observation_consult_path(organization, consult))
      expect(consult.suggested_teammate_ids).to include(other.id)
      expect(consult.people_status).to eq("suggested")
    end
  end

  describe "PATCH confirm_teammates" do
    let!(:consult) do
      create(
        :possible_observation_consult,
        organization: organization,
        creator_company_teammate: teammate,
        source_text: "Pat crushed it.",
        suggested_teammate_ids: [other.id]
      )
    end

    it "confirms people and enqueues extraction" do
      expect do
        patch confirm_teammates_organization_possible_observation_consult_path(organization, consult),
              params: { confirmed_teammate_ids: [other.id] }
      end.to have_enqueued_job(PossibleObservationConsultExtractionJob)

      consult.reload
      expect(consult.people_status).to eq("confirmed")
      expect(consult.confirmed_teammate_ids).to eq([other.id])
      expect(consult.extraction_status).to eq("pending")
    end
  end

  describe "draft promote" do
    let!(:consult) do
      create(
        :possible_observation_consult,
        :extracted,
        organization: organization,
        creator_company_teammate: teammate,
        confirmed_teammate_ids: [other.id],
        people_status: "confirmed"
      )
    end

    it "creates draft OGOs from included candidates" do
      item = consult.extraction_items.first
      expect do
        patch organization_possible_observation_consult_path(organization, consult),
              params: {
                commit: "Create draft OGOs from included",
                items: {
                  "0" => {
                    id: item[:id],
                    include: "1",
                    kind: item[:kind],
                    quote: item[:quote],
                    responder_company_teammate_id: teammate.id,
                    subject_company_teammate_id: other.id,
                    confidence: item[:confidence]
                  }
                }
              }
      end.to change(Observation, :count).by(1)

      observation = Observation.last
      expect(observation).to be_draft
      expect(observation.created_as_type).to eq(Observation::CREATED_AS_OGO_CONSULT)
      expect(observation.creator_company_teammate).to eq(teammate)
      expect(observation.observer).to eq(person)
      expect(consult.reload.extraction_items.first[:observation_id]).to eq(observation.id)
    end
  end

  describe "POST re_extract_with_stronger_model" do
    let!(:consult) do
      create(
        :possible_observation_consult,
        :extracted,
        organization: organization,
        creator_company_teammate: teammate,
        confirmed_teammate_ids: [other.id],
        people_status: "confirmed"
      )
    end

    before do
      consultation = OgConsultation.create!(
        subject: consult,
        organization: organization,
        kind: OgConsultation::KIND_OGO_SEARCH_CONSULT,
        status: "completed",
        billable: true,
        model_id: Llm::MultiTeammateMomentsExtractor.model_id,
        prompt_version: Llm::MultiTeammateMomentsExtractor.prompt_version,
        triggered_by_teammate: teammate,
        units_total: 1,
        units_completed: 1,
        completed_at: Time.current
      )
      result = OgoSearchResult.create!(og_consultation: consultation, items_count: 1)
      consultation.update!(result: result)
    end

    it "enqueues extraction with the stronger model" do
      expect do
        post re_extract_with_stronger_model_organization_possible_observation_consult_path(organization, consult)
      end.to have_enqueued_job(PossibleObservationConsultExtractionJob).with(
        consult.id,
        model_id: Llm::MultiTeammateMomentsExtractor.stronger_model_id
      )

      expect(consult.reload.extraction_status).to eq("pending")
    end
  end

  describe "GET show while processing" do
    let!(:consult) do
      create(
        :possible_observation_consult,
        organization: organization,
        creator_company_teammate: teammate,
        source_text: "Pat crushed it.",
        confirmed_teammate_ids: [other.id, teammate.id],
        people_status: "confirmed",
        extraction_status: "processing",
        extractions: {
          "version" => 1,
          "processed_teammate_ids" => [other.id],
          "items" => [
            {
              "id" => SecureRandom.uuid,
              "kind" => "kudos",
              "confidence" => 0.9,
              "quote" => "Pat crushed it.",
              "subject_company_teammate_id" => other.id,
              "responder_company_teammate_id" => teammate.id,
              "include" => true
            }
          ]
        }
      )
    end

    it "shows finished people while the status banner keeps running" do
      get organization_possible_observation_consult_path(organization, consult)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Results so far")
      expect(response.body).to include(other.person.display_name)
      expect(response.body).to include("1 of 2 people complete")
      expect(response.body).to include("OG Consult is processing")
      expect(response.body).not_to include("Review candidate OGOs")
    end
  end

  describe "GET extraction_status" do
    let!(:consult) do
      create(
        :possible_observation_consult,
        organization: organization,
        creator_company_teammate: teammate,
        confirmed_teammate_ids: [other.id, teammate.id],
        people_status: "confirmed",
        extraction_status: "processing",
        extractions: {
          "version" => 1,
          "processed_teammate_ids" => [other.id],
          "items" => []
        }
      )
    end

    it "includes progressive processed teammate count" do
      get extraction_status_organization_possible_observation_consult_path(organization, consult),
          headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["status"]).to eq("processing")
      expect(json["processed_teammates_count"]).to eq(1)
      expect(json["confirmed_teammates_count"]).to eq(2)
    end
  end

  describe "Google Meet import (coming soon)" do
    it "shows a disabled Connect control with coming-soon copy on new" do
      get new_organization_possible_observation_consult_path(organization)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Google Meet transcripts")
      expect(response.body).to include("Coming soon")
      expect(response.body).to include("upload or paste")
      expect(response.body).to include("data-bs-toggle=\"tooltip\"")
      expect(response.body).not_to include("Use this transcript")
    end

    it "rejects import while Meet connect is disabled" do
      expect do
        post import_google_meet_organization_possible_observation_consults_path(organization),
             params: { document_id: "doc123" }
      end.not_to change(PossibleObservationConsult, :count)

      expect(response).to redirect_to(new_organization_possible_observation_consult_path(organization))
      expect(flash[:alert]).to include("coming soon")
    end
  end

  describe "Zoom import (coming soon)" do
    it "shows a disabled Connect control with coming-soon copy on new" do
      get new_organization_possible_observation_consult_path(organization)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Zoom transcripts")
      expect(response.body).to include("Coming soon")
      expect(response.body).to include("Connect Zoom (transcripts)")
      expect(response.body).to include("data-bs-toggle=\"tooltip\"")
      expect(response.body).not_to include("Use this transcript")
    end

    it "rejects import while Zoom connect is disabled" do
      expect do
        post import_zoom_organization_possible_observation_consults_path(organization),
             params: { download_url: "https://zoom.us/rec/download/transcript" }
      end.not_to change(PossibleObservationConsult, :count)

      expect(response).to redirect_to(new_organization_possible_observation_consult_path(organization))
      expect(flash[:alert]).to include("coming soon")
    end
  end
end
