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

    it "confirms people and runs the stronger model when model=stronger" do
      expect do
        patch confirm_teammates_organization_possible_observation_consult_path(organization, consult),
              params: { confirmed_teammate_ids: [other.id], model: "stronger" }
      end.to have_enqueued_job(PossibleObservationConsultExtractionJob)
        .with(consult.id, model_id: Llm::MultiTeammateMomentsExtractor.stronger_model_id)

      expect(consult.reload.extraction_status).to eq("pending")
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

    it "creates draft OGOs from included candidates via Save all" do
      item = consult.extraction_items.first
      expect do
        patch organization_possible_observation_consult_path(organization, consult),
              params: {
                commit: "Save all",
                items: {
                  "0" => {
                    id: item[:id],
                    state: "included",
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

    it "creates a single draft OGO immediately via Create draft OGO now" do
      item = consult.extraction_items.first
      expect do
        patch organization_possible_observation_consult_path(organization, consult),
              params: {
                promote_item_id: item[:id],
                items: {
                  "0" => {
                    id: item[:id],
                    state: "needs_processed",
                    kind: item[:kind],
                    quote: item[:quote],
                    responder_company_teammate_id: teammate.id,
                    subject_company_teammate_id: other.id,
                    confidence: item[:confidence]
                  }
                }
              }
      end.to change(Observation, :count).by(1)

      expect(consult.reload.extraction_items.first[:observation_id]).to eq(Observation.last.id)
    end

    it "creates and publishes an OGO when the viewer is the observer" do
      item = consult.extraction_items.first
      patch organization_possible_observation_consult_path(organization, consult),
            params: {
              publish_item_id: item[:id],
              items: {
                "0" => {
                  id: item[:id],
                  state: "needs_processed",
                  kind: item[:kind],
                  quote: item[:quote],
                  responder_company_teammate_id: teammate.id,
                  subject_company_teammate_id: other.id,
                  confidence: item[:confidence]
                }
              }
            }

      observation = Observation.last
      expect(observation).to be_published
      expect(observation.observer_id).to eq(person.id)
      expect(observation.notifications).to be_empty
      expect(flash[:notice]).to include("Published OGO created")
    end

    it "creates a draft but warns when the viewer is not the observer on publish" do
      third = create(:company_teammate, organization: organization)
      item = consult.extraction_items.first
      patch organization_possible_observation_consult_path(organization, consult),
            params: {
              publish_item_id: item[:id],
              items: {
                "0" => {
                  id: item[:id],
                  state: "needs_processed",
                  kind: item[:kind],
                  quote: item[:quote],
                  responder_company_teammate_id: third.id,
                  subject_company_teammate_id: other.id,
                  confidence: item[:confidence]
                }
              }
            }

      observation = Observation.last
      expect(observation).to be_draft
      expect(flash[:alert]).to include("you can only publish OGOs where you are the observer")
    end

    it "preserves an already-promoted row when acting on another (disabled fields not wiped)" do
      id1 = SecureRandom.uuid
      id2 = SecureRandom.uuid
      consult.update!(
        extractions: {
          "version" => 1,
          "processed_teammate_ids" => [other.id],
          "items" => [
            { "id" => id1, "kind" => "kudos", "confidence" => 0.9, "quote" => "One",
              "responder_company_teammate_id" => teammate.id, "subject_company_teammate_id" => other.id,
              "observation_id" => nil, "include" => false },
            { "id" => id2, "kind" => "feedback", "confidence" => 0.9, "quote" => "Two",
              "responder_company_teammate_id" => teammate.id, "subject_company_teammate_id" => other.id,
              "observation_id" => nil, "include" => false }
          ]
        }
      )

      # Promote row 1.
      patch organization_possible_observation_consult_path(organization, consult),
            params: {
              promote_item_id: id1,
              items: {
                "0" => { id: id1, state: "included", kind: "kudos", quote: "One",
                         responder_company_teammate_id: teammate.id, subject_company_teammate_id: other.id },
                "1" => { id: id2, state: "needs_processed", quote: "Two" }
              }
            }
      obs1_id = consult.reload.extraction_items.find { |i| i[:id] == id1 }[:observation_id]
      expect(obs1_id).to be_present

      # Now act on row 2. Row 1 is locked, so the form would NOT submit its disabled
      # observer/subject/quote fields — only its hidden id/state/observation_id.
      patch organization_possible_observation_consult_path(organization, consult),
            params: {
              promote_item_id: id2,
              items: {
                "0" => { id: id1, state: "included", observation_id: obs1_id },
                "1" => { id: id2, state: "included", kind: "feedback", quote: "Two",
                         responder_company_teammate_id: teammate.id, subject_company_teammate_id: other.id }
              }
            }

      row1 = consult.reload.extraction_items.find { |i| i[:id] == id1 }
      expect(row1).to be_present
      expect(row1[:observation_id].to_i).to eq(obs1_id)
      expect(row1[:subject_company_teammate_id].to_i).to eq(other.id)
      expect(consult.extraction_groups_by_processed_teammate).to be_present
    end

    it "dismisses a single candidate immediately via Dismiss now" do
      item = consult.extraction_items.first
      patch organization_possible_observation_consult_path(organization, consult),
            params: {
              dismiss_item_id: item[:id],
              items: {
                "0" => {
                  id: item[:id],
                  state: "needs_processed",
                  quote: item[:quote]
                }
              }
            }

      dismissed = consult.reload.extraction_items.first
      expect(dismissed[:dismissed_at]).to be_present
      expect(dismissed[:dismissed_by_company_teammate_id]).to eq(teammate.id)
    end

    it "renders the tri-state controls and Save all on the review page" do
      get organization_possible_observation_consult_path(organization, consult)
      expect(response.body).to include("Save all")
      expect(response.body).to include(">Reviewing<")
      expect(response.body).to include(">Include<")
      expect(response.body).to include(">Dismiss<")
      expect(response.body).to include("Create draft OGO now")
      expect(response.body).to include("Create published OGO now (private)")
      expect(response.body).to include("Dismiss now")
      expect(response.body).to include("Consult OG again")
      expect(response.body).to include("Faster, but less powerful model")
      expect(response.body).to include("Slower, but more powerful model")
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

  describe "GET index" do
    it "shows pOGO total, dismissed, and promoted counts instead of status" do
      create(
        :possible_observation_consult,
        organization: organization,
        creator_company_teammate: teammate,
        display_name: "Counted consult",
        source_text: "Pat crushed it.",
        confirmed_teammate_ids: [other.id],
        people_status: "confirmed",
        extraction_status: "completed",
        extractions: {
          "version" => 1,
          "processed_teammate_ids" => [other.id],
          "items" => [
            { "id" => SecureRandom.uuid, "quote" => "a", "subject_company_teammate_id" => other.id, "observation_id" => 123 },
            { "id" => SecureRandom.uuid, "quote" => "b", "subject_company_teammate_id" => other.id, "dismissed_at" => Time.current.iso8601 },
            { "id" => SecureRandom.uuid, "quote" => "c", "subject_company_teammate_id" => other.id }
          ]
        }
      )

      get organization_possible_observation_consults_path(organization)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("pOGOs")
      expect(response.body).to include("Dismissed")
      expect(response.body).to include("Promoted")
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
