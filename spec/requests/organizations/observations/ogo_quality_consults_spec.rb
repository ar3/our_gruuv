# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Organizations::Observations::OgoQualityConsults", type: :request do
  include ActiveJob::TestHelper

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let!(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:observee_teammate) { create(:teammate, organization: organization) }
  let(:observation) do
    create(
      :observation,
      observer: person,
      company: organization,
      observation_type: "kudos",
      created_as_type: "kudos",
      story: "Pat closed the launch gap by shipping the fallback in one afternoon."
    )
  end

  before do
    sign_in_as_teammate_for_request(person, organization)
    PaperTrail.enabled = false
  end

  after do
    PaperTrail.enabled = true
  end

  describe "GET new kudos form" do
    it "includes the Consult OG about this OGO control" do
      get new_kudos_organization_observations_path(organization, draft_id: observation.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Consult OG about this OGO")
      expect(response.body).to include("Markdown is supported for formatting.")
      expect(response.body).to include("Run consultation")
      expect(response.body).to include("justify-content-between")
    end

    it "says Consult OG again when a consultation already exists" do
      create_ogo_quality_consultation!(observation: observation, status: "completed")

      get new_kudos_organization_observations_path(organization, draft_id: observation.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Consult OG again")
    end

    it "shows coaching instead of an OGO-worthy verdict" do
      create_ogo_quality_consultation!(
        observation: observation,
        status: "completed",
        payload: {
          "quality" => {
            "observation" => { "score" => 40, "notes" => "Add who did what." },
            "emotion" => { "score" => 82, "notes" => "Name the feeling." },
            "impact" => { "score" => 20, "notes" => "Who did this help?" },
            "summary" => "Keep the feeling, and add one camera-test detail.",
            "improvements" => ["Say what Pat actually did in the meeting."],
            "ogo_worthy" => true
          },
          "proposed_objects" => []
        }
      )

      get new_kudos_organization_observations_path(organization, draft_id: observation.id)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Keep the feeling, and add one camera-test detail.")
      expect(response.body).to include("Say what Pat actually did in the meeting.")
      expect(response.body).to include("If you are sure which Assignment, Ability, or Value was on display")
      expect(response.body).not_to include("OGO-worthy")
      expect(response.body).not_to include("does not consider this OGO-worthy")
    end
  end

  describe "POST ogo_quality_consult" do
    it "creates a consultation without writing ratings and enqueues the job" do
      rating_count = observation.observation_ratings.count

      expect do
        post ogo_quality_consult_organization_observation_path(organization, observation),
             params: {
               observation: { story: observation.story, observation_type: "kudos" },
               observee_ids: observation.observees.map(&:teammate_id)
             }
      end.to have_enqueued_job(OgoQualityJob)

      expect(response).to redirect_to(
        new_kudos_organization_observations_path(organization, draft_id: observation.id, ogo_consult: 1)
      )
      run = observation.reload.latest_ogo_quality_consultation
      expect(run).to be_present
      expect(run.status).to eq("pending")
      expect(run.kind).to eq(OgConsultation::KIND_OGO_QUALITY)
      expect(observation.observation_ratings.count).to eq(rating_count)
    end

    it "persists a new draft then consults when the form is still unsaved" do
      expect do
        post ogo_quality_consult_organization_observation_path(organization, :new),
             params: {
               observation: {
                 story: "Alex named the risk before we shipped.",
                 observation_type: "kudos",
                 privacy_level: "observed_and_managers"
               },
               observee_ids: [observee_teammate.id]
             }
      end.to change(Observation, :count).by(1).and have_enqueued_job(OgoQualityJob)

      created = Observation.order(:id).last
      expect(created.story).to include("Alex named the risk")
      expect(created.observees.map(&:teammate_id)).to include(observee_teammate.id)
      expect(created.latest_ogo_quality_consultation).to be_present
    end

    it "does not start when story is blank" do
      expect do
        post ogo_quality_consult_organization_observation_path(organization, observation),
             params: {
               observation: { story: "   ", observation_type: "kudos" },
               observee_ids: observation.observees.map(&:teammate_id)
             }
      end.not_to have_enqueued_job(OgoQualityJob)

      expect(response).to redirect_to(new_organization_observation_path(organization))
      expect(flash[:alert]).to include("observee")
    end
  end

  describe "GET ogo_quality_consult_status" do
    it "returns JSON for the latest consultation" do
      create_ogo_quality_consultation!(observation: observation, status: "processing")

      get ogo_quality_consult_status_organization_observation_path(organization, observation),
          headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["status"]).to eq("processing")
    end
  end
end
