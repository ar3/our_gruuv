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
            "text" => "Pat crushed the demo and delivered an outstanding result for the team.",
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

      it "stores full results and creates consultation batches when the job runs" do
        stub_successful_slack_search

        perform_enqueued_jobs do
          post organization_company_teammate_possible_observation_slack_searches_path(organization, subject),
               params: { possible_observation_slack_search: { window_days: 90 } }
        end

        search = PossibleObservationSlackSearch.order(:id).last
        expect(search.reload.search_status).to eq("completed")
        expect(search.messages_count).to eq(1)
        expect(search.filtered_messages_count).to eq(1)
        expect(search.raw_results_file).to be_attached
        expect(search.message_batches.count).to eq(1)
        expect(search.raw_messages.first[:text]).to include("Pat crushed the demo")
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

    it "renders the unified search page with consultation sections" do
      get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("consultation-1")
      expect(response.body).to include("Consultation 1 of 1")
      expect(response.body).to include("1 fetched · 1 for consultation")
      expect(response.body).to include("Download messages")
      expect(response.body).to include("Messages in this consultation")
      expect(response.body).to include("500 messages")
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

  describe "batch extract and review" do
    let!(:search) do
      create(
        :possible_observation_slack_search,
        :completed,
        organization: organization,
        creator_company_teammate: teammate,
        subject_company_teammate: subject
      )
    end
    let(:batch) { search.message_batches.first }

    it "enqueues extraction on the batch and returns to the search consultation section" do
      expect {
        post extract_organization_company_teammate_possible_observation_slack_search_batch_path(
          organization, subject, search, batch
        )
      }.to have_enqueued_job(PossibleObservationSlackSearchExtractionJob)

      expect(batch.reload.extraction_status).to eq("pending")
      expect(response).to redirect_to(
        organization_company_teammate_possible_observation_slack_search_path(
          organization, subject, search, anchor: "consultation-#{batch.position}"
        )
      )
    end

    it "enqueues extraction with the stronger model when model=stronger" do
      expect {
        post extract_organization_company_teammate_possible_observation_slack_search_batch_path(
          organization, subject, search, batch, model: "stronger"
        )
      }.to have_enqueued_job(PossibleObservationSlackSearchExtractionJob)
        .with(batch.id, model_id: Llm::SlackMomentsExtractor.stronger_model_id)

      expect(batch.reload.extraction_status).to eq("pending")
    end

    it "renders the model-choice dropdown on the consultation section" do
      get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
      expect(response.body).to include("Consult OG to find potential OGOs")
      expect(response.body).to include("Faster, but less powerful model")
      expect(response.body).to include("Slower, but more powerful model")
    end

    context "when extracted" do
      let!(:search) do
        create(
          :possible_observation_slack_search,
          :extracted,
          organization: organization,
          creator_company_teammate: teammate,
          subject_company_teammate: subject
        )
      end
      let(:batch) { search.message_batches.first }

      it "redirects batch show to the unified search consultation section" do
        get organization_company_teammate_possible_observation_slack_search_batch_path(organization, subject, search, batch)
        expect(response).to redirect_to(
          organization_company_teammate_possible_observation_slack_search_path(
            organization, subject, search, anchor: "consultation-#{batch.position}"
          )
        )
      end

      it "renders the review form on the unified search page" do
        get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Review candidate OGOs")
        expect(response.body).to include("Save all")
        expect(response.body).to include("Observer (speaker)")
        expect(response.body).to include(">Actions<")
        expect(response.body).to include("Reviewing")
        expect(response.body).to include(">Include<")
        expect(response.body).to include("data-slack-state")
        expect(response.body).to include("Kudos")
        expect(response.body).to include("Feedback")
        expect(response.body).not_to include("Quick note")
      end

      it "renders confidence-band analytics under the consultation status" do
        items = [
          { "id" => SecureRandom.uuid, "confidence" => 0.91, "quote" => "high", "kind" => "kudos",
            "include" => true, "responder_company_teammate_id" => subject.id, "subject_company_teammate_id" => subject.id },
          { "id" => SecureRandom.uuid, "confidence" => 0.78, "quote" => "mid-high", "kind" => "kudos",
            "include" => true, "responder_company_teammate_id" => subject.id, "subject_company_teammate_id" => subject.id },
          { "id" => SecureRandom.uuid, "confidence" => 0.76, "quote" => "mid-high-2", "kind" => "feedback",
            "include" => true, "responder_company_teammate_id" => subject.id, "subject_company_teammate_id" => subject.id },
          { "id" => SecureRandom.uuid, "confidence" => 0.62, "quote" => "mid", "kind" => "feedback",
            "include" => false, "responder_company_teammate_id" => subject.id, "subject_company_teammate_id" => subject.id }
        ]
        batch.replace_extraction_items!(items)

        get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)

        expect(response.body).to include("3 potential OGOs that OG is 75%+ confident on")
        expect(response.body).to include("visible on 1-by-1 check-in pages")
        expect(response.body).to include("1 potential OGO that OG is between 50–75% confident on")
        expect(response.body).to include("these are defaulted to Reviewing below")
      end

      it "prefixes the already-run (default) model with Re-run and the other with Try" do
        get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
        expect(response.body).to include("Consult OG again")
        expect(response.body).to include("Re-run: Faster, but less powerful model")
        expect(response.body).to include("Try: Slower, but more powerful model")
      end

      it "prefixes the stronger model with Re-run when it was the last model run" do
        batch.mark_extraction_completed!(
          items: batch.extraction_items,
          model_id: Llm::SlackMomentsExtractor.stronger_model_id
        )

        get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
        expect(response.body).to include("Re-run: Slower, but more powerful model")
        expect(response.body).to include("Try: Faster, but less powerful model")
      end

      it "shows the rating and linked object name as text above the generated rationale" do
        assignment = create(:assignment, company: organization, title: "Own the launch")
        item = batch.extraction_items.first.to_h.merge(
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
        batch.replace_extraction_items!([item])

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

      it "saves include/kind updates and returns to the consultation section" do
        item = batch.extraction_items.first
        patch organization_company_teammate_possible_observation_slack_search_batch_path(organization, subject, search, batch),
              params: {
                items: {
                  "0" => {
                    id: item[:id],
                    state: "needs_processed",
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
          organization_company_teammate_possible_observation_slack_search_path(
            organization, subject, search, anchor: "consultation-#{batch.position}"
          )
        )
        updated = batch.reload.extraction_items.first
        expect(updated[:include]).to eq(false)
        expect(updated[:kind]).to eq("feedback")
      end

      it "dismisses a candidate via Save all and can restore it" do
        item = batch.extraction_items.first
        patch organization_company_teammate_possible_observation_slack_search_batch_path(organization, subject, search, batch),
              params: {
                commit: "Save all",
                items: {
                  "0" => {
                    id: item[:id],
                    state: "dismissed",
                    quote: item[:quote],
                    channel_id: item[:channel_id],
                    ts: item[:ts]
                  }
                }
              }

        dismissed = batch.reload.extraction_items.first
        expect(dismissed[:dismissed_at]).to be_present
        expect(dismissed[:dismissed_by_company_teammate_id]).to eq(teammate.id)
        expect(dismissed[:include]).to eq(false)

        patch organization_company_teammate_possible_observation_slack_search_batch_path(organization, subject, search, batch),
              params: {
                items: {
                  "0" => {
                    id: item[:id],
                    state: "needs_processed",
                    quote: item[:quote],
                    channel_id: item[:channel_id],
                    ts: item[:ts]
                  }
                }
              }

        restored = batch.reload.extraction_items.first
        expect(restored[:dismissed_at]).to be_nil
        expect(restored[:dismissed_by_company_teammate_id]).to be_nil
      end

      it "dismisses a single candidate immediately via Dismiss now" do
        item = batch.extraction_items.first
        patch organization_company_teammate_possible_observation_slack_search_batch_path(organization, subject, search, batch),
              params: {
                dismiss_item_id: item[:id],
                items: {
                  "0" => {
                    id: item[:id],
                    state: "needs_processed",
                    quote: item[:quote],
                    channel_id: item[:channel_id],
                    ts: item[:ts]
                  }
                }
              }

        dismissed = batch.reload.extraction_items.first
        expect(dismissed[:dismissed_at]).to be_present
        expect(dismissed[:dismissed_by_company_teammate_id]).to eq(teammate.id)
      end

      it "renders the tri-state status controls and per-row actions on the review form" do
        get organization_company_teammate_possible_observation_slack_search_path(organization, subject, search)
        expect(response.body).to include("Reviewing")
        expect(response.body).to include("Dismiss now")
        expect(response.body).to include("Create draft OGO now")
        expect(response.body).to include("Create published OGO now (private)")
        expect(response.body).to include("data-slack-state")
      end

      it "creates a single draft OGO immediately via Create draft OGO now" do
        item = batch.extraction_items.first
        expect do
          patch organization_company_teammate_possible_observation_slack_search_batch_path(organization, subject, search, batch),
                params: {
                  promote_item_id: item[:id],
                  items: {
                    "0" => {
                      id: item[:id],
                      state: "needs_processed",
                      kind: item[:kind],
                      quote: item[:quote],
                      responder_company_teammate_id: subject.id,
                      subject_company_teammate_id: subject.id,
                      channel_id: item[:channel_id],
                      ts: item[:ts]
                    }
                  }
                }
        end.to change(Observation, :count).by(1)

        observation = Observation.last
        expect(observation).to be_draft
        expect(batch.reload.extraction_items.first[:observation_id]).to eq(observation.id)
      end

      it "preserves other rows' observer/subject/quote when acting on one row (disabled fields not wiped)" do
        id1 = SecureRandom.uuid
        id2 = SecureRandom.uuid
        batch.replace_extraction_items!([
          { "id" => id1, "kind" => "kudos", "confidence" => 0.9, "quote" => "Quote one",
            "responder_company_teammate_id" => subject.id, "subject_company_teammate_id" => subject.id,
            "channel_id" => "C1", "ts" => "1710000000.000100", "include" => false },
          { "id" => id2, "kind" => "feedback", "confidence" => 0.9, "quote" => "Quote two",
            "responder_company_teammate_id" => subject.id, "subject_company_teammate_id" => subject.id,
            "channel_id" => "C1", "ts" => "1710000000.000200", "include" => false }
        ])

        # Dismiss row 2. Row 1 stays "Reviewing", so the browser would NOT submit its
        # disabled observer/subject/quote/kind fields — only its hidden fields.
        patch organization_company_teammate_possible_observation_slack_search_batch_path(organization, subject, search, batch),
              params: {
                dismiss_item_id: id2,
                items: {
                  "0" => { id: id1, state: "needs_processed", channel_id: "C1", ts: "1710000000.000100" },
                  "1" => { id: id2, state: "needs_processed", channel_id: "C1", ts: "1710000000.000200" }
                }
              }

        row1 = batch.reload.extraction_items.find { |i| i[:id] == id1 }
        expect(row1[:subject_company_teammate_id].to_i).to eq(subject.id)
        expect(row1[:responder_company_teammate_id].to_i).to eq(subject.id)
        expect(row1[:quote]).to eq("Quote one")
        expect(row1[:kind]).to eq("kudos")
      end

      it "creates and publishes an OGO when the viewer is the observer" do
        item = batch.extraction_items.first
        patch organization_company_teammate_possible_observation_slack_search_batch_path(organization, subject, search, batch),
              params: {
                publish_item_id: item[:id],
                items: {
                  "0" => {
                    id: item[:id],
                    state: "needs_processed",
                    kind: item[:kind],
                    quote: item[:quote],
                    responder_company_teammate_id: teammate.id,
                    subject_company_teammate_id: subject.id,
                    channel_id: item[:channel_id],
                    ts: item[:ts]
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
        other = create(:company_teammate, organization: organization)
        item = batch.extraction_items.first
        patch organization_company_teammate_possible_observation_slack_search_batch_path(organization, subject, search, batch),
              params: {
                publish_item_id: item[:id],
                items: {
                  "0" => {
                    id: item[:id],
                    state: "needs_processed",
                    kind: item[:kind],
                    quote: item[:quote],
                    responder_company_teammate_id: other.id,
                    subject_company_teammate_id: subject.id,
                    channel_id: item[:channel_id],
                    ts: item[:ts]
                  }
                }
              }

        observation = Observation.last
        expect(observation).to be_draft
        expect(flash[:alert]).to include("you can only publish OGOs where you are the observer")
      end

      it "creates draft OGOs from included candidates" do
        item = batch.extraction_items.first
        expect do
          patch organization_company_teammate_possible_observation_slack_search_batch_path(
            organization, subject, search, batch
          ), params: {
            commit: "Save all",
            items: {
              "0" => {
                id: item[:id],
                state: "included",
                kind: item[:kind],
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
        end.to change(Observation, :count).by(1)

        expect(response).to redirect_to(
          organization_company_teammate_possible_observation_slack_search_path(
            organization, subject, search, anchor: "consultation-#{batch.position}"
          )
        )
        follow_redirect!
        expect(response.body).to include("Open draft OGO")
        expect(response.body).to include("Save all")

        observation = Observation.last
        expect(observation).to be_draft
        expect(observation.created_as_type).to eq(Observation::CREATED_AS_SLACK_SOURCE)
        expect(observation.creator_company_teammate).to eq(teammate)
        expect(batch.reload.extraction_items.first[:observation_id]).to eq(observation.id)
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
          expect(response.body).to include("Save all")
        end
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

    it "lists prior searches with a single Open to the unified search page" do
      expect(prior_search.message_batches.count).to eq(1)

      get ogos_source_from_slack_organization_company_teammate_path(organization, subject)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Run a new search")
      expect(response.body).to include("Prior search about Pat")
      expect(response.body).to include("1 fetched · 1 for consultation")
      expect(response.body).to include(
        organization_company_teammate_possible_observation_slack_search_path(organization, subject, prior_search)
      )
      expect(response.body).to match(/1\s+consultation/)
      expect(response.body).not_to include("Consultation 1 of 1; Newest")
    end
  end
end
