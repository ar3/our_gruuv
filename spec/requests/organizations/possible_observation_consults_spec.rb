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
    it "saves paste content, suggests teammates, and enqueues the first-pass job" do
      expect do
        post organization_possible_observation_consults_path(organization),
             params: {
               possible_observation_consult: {
                 display_name: "Weekly sync",
                 source_text: "Pat did a great job shipping the launch this week."
               }
             }
      end.to change(PossibleObservationConsult, :count).by(1)
        .and have_enqueued_job(PossibleObservationConsultFirstPassJob)

      consult = PossibleObservationConsult.last
      expect(response).to redirect_to(organization_possible_observation_consult_path(organization, consult))
      expect(consult.suggested_teammate_ids).to include(other.id)
      expect(consult.people_status).to eq("suggested")
      expect(consult.first_pass_status).to eq("pending")
    end
  end

  describe "PATCH confirm_teammates" do
    let!(:consult) do
      create(
        :possible_observation_consult,
        organization: organization,
        creator_company_teammate: teammate,
        source_text: <<~VTT,
          WEBVTT

          1
          00:12:00.000 --> 00:12:05.000
          Pat Subject: Pat crushed it this week.
        VTT
        suggested_teammate_ids: [other.id]
      )
    end

    before do
      consult.update!(first_pass_status: "completed")
      PossibleObservationConsults::BuildSpeakerMapService.call(consult: consult)
    end

    it "confirms people from the cue map and enqueues extraction" do
      cue_id = Transcripts::MomentCuesService.call(raw: consult.source_raw).first.fetch("id")
      expect do
        patch confirm_teammates_organization_possible_observation_consult_path(organization, consult),
              params: {
                speaker_map: {
                  "Pat Subject" => { certainty: "certain", company_teammate_id: other.id }
                },
                cue_annotations: {
                  cue_id => {
                    ogo_worthy: "1",
                    observee_certainty: "certain",
                    observee_company_teammate_id: other.id
                  }
                }
              }
      end.to have_enqueued_job(PossibleObservationConsultExtractionJob)

      consult.reload
      expect(consult.people_status).to eq("confirmed")
      expect(consult.confirmed_teammate_ids).to eq([other.id])
      expect(consult.extraction_status).to eq("pending")
      expect(consult.speaker_map_labels["Pat Subject"][:certainty]).to eq("certain")
      expect(consult.cue_annotation_rows[cue_id][:cue_status]).to eq("ogo_worthy")
      expect(consult.cue_annotation_rows[cue_id][:observee_company_teammate_id]).to eq(other.id)
    end

    it "enqueues Step 3 extraction with Sonnet" do
      cue_id = Transcripts::MomentCuesService.call(raw: consult.source_raw).first.fetch("id")
      expect do
        patch confirm_teammates_organization_possible_observation_consult_path(organization, consult),
              params: {
                speaker_map: {
                  "Pat Subject" => { certainty: "certain", company_teammate_id: other.id }
                },
                cue_annotations: {
                  cue_id => { ogo_worthy: "1", observee_certainty: "uncertain" }
                }
              }
      end.to have_enqueued_job(PossibleObservationConsultExtractionJob)
        .with(consult.id, model_id: Llm::MultiTeammateMomentsExtractor.model_id)

      expect(Llm::MultiTeammateMomentsExtractor.model_id).to include("claude-sonnet-4-5")
      expect(consult.reload.extraction_status).to eq("pending")
    end

    it "still accepts legacy checkbox confirmed_teammate_ids" do
      patch confirm_teammates_organization_possible_observation_consult_path(organization, consult),
            params: { confirmed_teammate_ids: [other.id] }
      expect(consult.reload.confirmed_teammate_ids).to eq([other.id])
    end
  end

  describe "POST create with debug=true" do
    it "stores prompt_debug and enqueues first pass" do
      expect do
        post organization_possible_observation_consults_path(organization, debug: true),
             params: {
               possible_observation_consult: {
                 display_name: "Debug hone",
                 source_text: <<~VTT,
                   WEBVTT

                   1
                   00:01:00.000 --> 00:01:02.000
                   Pat Subject: Pat did a great job shipping the launch this week.
                 VTT
                 prompt_debug: "true"
               }
             }
      end.to have_enqueued_job(PossibleObservationConsultFirstPassJob)

      consult = PossibleObservationConsult.last
      expect(consult.prompt_debug?).to be(true)
      expect(consult.first_pass_status).to eq("pending")
      expect(response).to redirect_to(organization_possible_observation_consult_path(organization, consult))
    end
  end

  describe "GET new with debug=true" do
    it "shows the prompt-debug banner" do
      get new_organization_possible_observation_consult_path(organization, debug: true)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Prompt debug mode is on for this consult")
      expect(response.body).to include("Save labels (no drafts)")
      expect(response.body).to include("?debug=true")
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

    it "renders the product Include / per-row promote controls when the consult is not prompt-debug" do
      get organization_possible_observation_consult_path(organization, consult)
      expect(response.body).to include("Save all")
      expect(response.body).not_to include("Save labels (no drafts)")
      expect(response.body).to include(">Keep Reviewing<")
      expect(response.body).to include(">Create Draft OGO<")
      expect(response.body).not_to include(">Would create draft OGO<")
      expect(response.body).to include("What we&#39;ll do when we Save all at the end")
      expect(response.body).to include("…or act on just this one right now")
      expect(response.body).to include("data-bs-toggle=\"collapse\"")
      expect(response.body).to include("Create draft OGO now")
      expect(response.body).to include("Create published OGO now (private)")
      expect(response.body).to include("Dismiss now")
      expect(response.body).not_to include("Consult OG again")
      expect(response.body).to include("confident in this suggestion")
      expect(response.body).to include('rows="11"')
      expect(response.body).not_to include("Faster, but less powerful model")
      expect(response.body).not_to include("Slower, but more powerful model")
    end

    it "lists completed step 3 candidates in transcript time order without person headings" do
      third_person = create(:person, full_name: "Late Subject", preferred_name: "Late")
      third = create(:company_teammate, person: third_person, organization: organization)
      create(:employment_tenure, teammate: third, company: organization, started_at: 1.year.ago, ended_at: nil)
      third.update!(first_employed_at: 1.year.ago)

      early_text = "Early shout out with enough overlapping text for cue matching"
      late_text = "Later shout out with enough overlapping text for cue matching"
      consult.update!(
        confirmed_teammate_ids: [other.id, third.id],
        cue_annotations: {
          "moments" => [
            {
              "id" => "late-cue",
              "start" => "00:10:00.000",
              "end" => "00:10:05.000",
              "start_ms" => 600_000,
              "end_ms" => 605_000,
              "text" => late_text
            },
            {
              "id" => "early-cue",
              "start" => "00:01:00.000",
              "end" => "00:01:05.000",
              "start_ms" => 60_000,
              "end_ms" => 65_000,
              "text" => early_text
            }
          ]
        },
        extractions: {
          "version" => 1,
          "processed_teammate_ids" => [other.id, third.id],
          "items" => [
            {
              "id" => "late-item",
              "kind" => "kudos",
              "confidence" => 0.8,
              "quote" => late_text,
              "full_quote" => late_text,
              "suggested_rating" => "exceeded",
              "suggested_rateable_type" => "Ability",
              "suggested_rateable_name" => "Delivery",
              "responder_company_teammate_id" => teammate.id,
              "subject_company_teammate_id" => third.id,
              "include" => false
            },
            {
              "id" => "early-item",
              "kind" => "kudos",
              "confidence" => 0.7,
              "quote" => early_text,
              "full_quote" => early_text,
              "suggested_rating" => "met",
              "suggested_rateable_type" => "Ability",
              "suggested_rateable_name" => "Delivery",
              "responder_company_teammate_id" => teammate.id,
              "subject_company_teammate_id" => other.id,
              "include" => false
            }
          ]
        }
      )

      get organization_possible_observation_consult_path(organization, consult)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Step 3 · Review candidate OGOs")
      expect(response.body).not_to include("Results so far")
      expect(response.body).to include("00:01:00.000")
      expect(response.body).to include("confident in this suggestion")
      expect(response.body).to include("Suggested:")
      expect(response.body).to include('rows="11"')
      expect(response.body.index(early_text)).to be < response.body.index(late_text)
    end

    it "keeps observer and subject editable on step 3 review" do
      item = consult.extraction_items.first.to_h.merge(
        "observer_unknown" => true,
        "observer_alternates" => [
          { "company_teammate_id" => other.id, "name" => other.person.display_name }
        ]
      )
      consult.update!(extractions: consult.extractions.merge("items" => [item]))

      get organization_possible_observation_consult_path(organization, consult)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Might also be")
      expect(response.body).to include("ogo-identity-alternates")
      expect(response.body).to include('name="items[0][responder_company_teammate_id]"')
      expect(response.body).to include("form-select")
      expect(response.body).to include(other.person.display_name)
    end
  end

  describe "prompt-debug hone loop" do
    let(:vtt_source) do
      <<~VTT
        WEBVTT

        1
        00:12:22.880 --> 00:12:35.829
        Corbin Dodson: I just want to shout out Brett. He's been super helpful.

        2
        00:12:36.160 --> 00:12:47.399
        Corbin Dodson: Brett has answered any and every question during training.
      VTT
    end

    let!(:consult) do
      create(
        :possible_observation_consult,
        :extracted,
        :prompt_debug,
        organization: organization,
        creator_company_teammate: teammate,
        confirmed_teammate_ids: [other.id],
        people_status: "confirmed",
        source_text: vtt_source,
        speaker_map: {
          "version" => 1,
          "labels" => {
            "Corbin Dodson" => {
              "raw_label" => "Corbin Dodson",
              "certainty" => "uncertain",
              "company_teammate_id" => nil,
              "cue_count" => 2,
              "kind" => "speech",
              "manual" => false
            }
          }
        }
      )
    end

    before do
      item = consult.extraction_items.first.to_h.merge(
        "full_quote" => "Brett has answered any and every question during training.",
        "speaker_label" => "Corbin Dodson",
        "quote" => "Brett has answered any and every question during training."
      )
      consult.update!(
        extractions: consult.extractions.merge(
          "items" => [item],
          "ai_items" => [item.deep_dup]
        )
      )
    end

    it "renders prompt-debug hone controls on the review page" do
      get organization_possible_observation_consult_path(organization, consult)
      expect(response.body).to include("Prompt debug mode is on for this consult")
      expect(response.body).to include("Save labels (no drafts)")
      expect(response.body).to include("Save all (create drafts)")
      expect(response.body).to include("Download prompt-debug JSON")
      expect(response.body).to include("Transcript")
      expect(response.body).to include("Show in transcript")
      expect(response.body).to include("Corbin Dodson")
      expect(response.body).to include(">Keep Reviewing<")
      expect(response.body).to include(">Would create draft OGO<")
      expect(response.body).to include(">Dismiss<")
      expect(response.body).not_to include("Create draft OGO now")
    end

    it "shows the prompt-debug banner and step-2 cue map when first pass is complete" do
      consult.update!(
        people_status: "suggested",
        confirmed_teammate_ids: [],
        extraction_status: "ready",
        first_pass_status: "completed"
      )
      PossibleObservationConsults::BuildSpeakerMapService.call(consult: consult)
      get organization_possible_observation_consult_path(organization, consult)
      expect(response.body).to include("Prompt debug mode is on for this consult")
      expect(response.body).to include("Step 1 • Upload, Paste, Connect meeting transcript")
      expect(response.body).to include("bi-check-circle-fill")
      expect(response.body).to include("Step 2 • Who is observing whom")
      expect(response.body).to include("OG tried to figure out who was talking and who they were talking about")
      expect(response.body).to include("but we need you to verify")
      expect(response.body).to include("Step 3 • Review the content and create the OGOs")
      expect(response.body).to include("associate the right Abilities, Assignments, or Values")
      expect(response.body).to include("OGO-worthy")
      expect(response.body).to include("merged into one cue")
      expect(response.body).to include("Confirm people and continue to Step 3")
    end

    it "shows the first-pass waiting banner while the cheap pass runs" do
      consult.update!(
        people_status: "suggested",
        confirmed_teammate_ids: [],
        extraction_status: "ready",
        first_pass_status: "processing"
      )
      get organization_possible_observation_consult_path(organization, consult)
      expect(response.body).to include("Step 1 • Upload, Paste, Connect meeting transcript")
      expect(response.body).to include("Step 2 • Who is observing whom")
      expect(response.body).to include("First pass in progress")
      expect(response.body).to include("Step 3 • Review the content and create the OGOs")
      expect(response.body).to include("Doing the first pass to see who is observing whom")
    end

    it "saves speaker map resolutions" do
      patch update_speaker_map_organization_possible_observation_consult_path(organization, consult),
            params: {
              speaker_map: {
                "Corbin Dodson" => {
                  certainty: "certain",
                  company_teammate_id: teammate.id
                }
              }
            }

      expect(response).to redirect_to(organization_possible_observation_consult_path(organization, consult))
      entry = consult.reload.speaker_map_labels["Corbin Dodson"]
      expect(entry[:certainty]).to eq("certain")
      expect(entry[:company_teammate_id]).to eq(teammate.id)
      expect(entry[:manual]).to eq(true)
      expect(consult.extraction_items.first[:responder_company_teammate_id].to_i).to eq(teammate.id)
    end

    it "saves labels without creating draft OGOs" do
      item = consult.extraction_items.first
      expect do
        patch save_labels_organization_possible_observation_consult_path(organization, consult),
              params: {
                items: {
                  "0" => {
                    id: item[:id],
                    state: "included",
                    kind: "feedback",
                    quote: "Corrected quote for prompt hone",
                    responder_company_teammate_id: teammate.id,
                    subject_company_teammate_id: other.id,
                    confidence: item[:confidence]
                  }
                }
              }
      end.not_to change(Observation, :count)

      expect(response).to redirect_to(organization_possible_observation_consult_path(organization, consult))
      follow_redirect!
      expect(response.body).to include("Labels saved (no drafts created)")

      saved = consult.reload.extraction_items.first
      expect(saved[:quote]).to eq("Corrected quote for prompt hone")
      expect(saved[:kind]).to eq("feedback")
      expect(saved[:include]).to eq(true)
      expect(saved[:observation_id]).to be_blank
      expect(consult.ai_extraction_items.first[:quote]).to eq(item[:quote])
    end

    it "downloads prompt-debug JSON with ai defaults vs labels" do
      item = consult.extraction_items.first
      consult.replace_extraction_items!(
        [
          item.to_h.stringify_keys.merge(
            "quote" => "Human-corrected quote",
            "include" => false,
            "dismissed_at" => Time.current.iso8601
          )
        ]
      )

      get download_prompt_debug_organization_possible_observation_consult_path(organization, consult)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/json")
      payload = JSON.parse(response.body)
      expect(payload["purpose"]).to eq("ogo_consult_prompt_debug")
      expect(payload.dig("consult", "prompt_debug")).to be(true)
      expect(payload["ai_items"].first["quote"]).to eq(item[:quote])
      expect(payload["labeled_items"].first["quote"]).to eq("Human-corrected quote")
      expect(payload["diff"].first["outcome"]).to eq("dismissed")
      expect(payload["diff"].first["field_changes"]).to include("quote")
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
      create(
        :possible_observation_consult,
        :prompt_debug,
        organization: organization,
        creator_company_teammate: teammate,
        display_name: "Debug hone consult",
        source_text: "Pat crushed it."
      )

      get organization_possible_observation_consults_path(organization)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("pOGOs")
      expect(response.body).to include("Dismissed")
      expect(response.body).to include("Promoted")
      expect(response.body).to include("1 prompt-debug run")
      expect(response.body).to include("Debug hone consult")
      expect(response.body).to include(">Debug<")
    end

    it "lists the viewer's Slack searches next to transcript consults" do
      create(:teammate_identity, :slack_search, teammate: teammate)
      search = create(
        :possible_observation_slack_search,
        :completed,
        organization: organization,
        creator_company_teammate: teammate,
        subject_company_teammate: other,
        display_name: "Slack search about Pat (last 30 days)"
      )

      get organization_possible_observation_consults_path(organization)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Slack searches")
      expect(response.body).to include(search.display_name)
      expect(response.body).to include(
        organization_company_teammate_possible_observation_slack_search_path(organization, other, search)
      )
    end
  end

  describe "GET slack_search_statuses" do
    it "returns hub phase payloads for the viewer's searches" do
      create(
        :possible_observation_slack_search,
        organization: organization,
        creator_company_teammate: teammate,
        subject_company_teammate: other,
        search_status: "processing"
      )

      get slack_search_statuses_organization_possible_observation_consults_path(organization),
          headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["polling"]).to be(true)
      expect(json["searches"].first["phase"]).to eq("searching")
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

  describe "GET first_pass_status" do
    let!(:consult) do
      create(
        :possible_observation_consult,
        organization: organization,
        creator_company_teammate: teammate,
        first_pass_status: "processing"
      )
    end

    it "signals the poller to keep waiting while in flight" do
      get first_pass_status_organization_possible_observation_consult_path(organization, consult),
          headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json["status"]).to eq("processing")
      expect(json["polling"]).to eq(true)
      expect(json["reload"]).to eq(false)
    end

    it "signals reload when the first pass completes" do
      consult.update!(first_pass_status: "completed")
      get first_pass_status_organization_possible_observation_consult_path(organization, consult),
          headers: { "Accept" => "application/json" }

      json = response.parsed_body
      expect(json["status"]).to eq("completed")
      expect(json["polling"]).to eq(false)
      expect(json["reload"]).to eq(true)
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
