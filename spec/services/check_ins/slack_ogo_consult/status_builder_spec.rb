# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SlackOgoConsult::StatusBuilder do
  include Rails.application.routes.url_helpers

  let(:organization) { create(:organization, :company) }
  let(:viewer) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:search) do
    create(
      :possible_observation_slack_search,
      :completed,
      organization: organization,
      creator_company_teammate: viewer,
      subject_company_teammate: subject_teammate
    )
  end
  let(:batch) { search.message_batches.first }
  let(:helpers) do
    Class.new do
      include Rails.application.routes.url_helpers
      def default_url_options = { host: "www.example.com" }
    end.new
  end

  def build_payload
    described_class.call(
      search: search,
      rateable_type: "Assignment",
      rateable_id: assignment.id,
      organization: organization,
      subject_teammate: subject_teammate,
      object_name: assignment.title,
      helpers: helpers
    )
  end

  def create_completed_consultation(created_at:, model_id: Llm::SlackMomentsExtractor.model_id)
    batch.update!(extraction_status: "completed")
    consultation = OgConsultations::StartOgoSearch.call(
      subject: batch,
      kind: OgConsultation::KIND_OGO_SEARCH_SLACK,
      organization_id: organization.id,
      triggered_by_teammate_id: viewer.id,
      units_total: 1,
      extraction_version: 1,
      model_id: model_id,
      prompt_version: "1"
    )
    consultation.update!(status: "completed", completed_at: created_at)
    consultation.update_columns(created_at: created_at, updated_at: created_at)
    consultation
  end

  it "allows refresh search only when the latest consult is older than 3 days" do
    create_completed_consultation(created_at: 2.days.ago)
    expect(build_payload[:can_refresh_search]).to eq(false)
  end

  it "allows refresh search when the latest consult is older than 3 days" do
    create_completed_consultation(created_at: 4.days.ago)
    expect(build_payload[:can_refresh_search]).to eq(true)
  end

  it "allows stronger-model re-run only when the latest run is not already stronger" do
    create_completed_consultation(created_at: 1.day.ago)
    expect(build_payload[:can_stronger_model]).to eq(true)

    create_completed_consultation(
      created_at: Time.current,
      model_id: Llm::SlackMomentsExtractor.stronger_model_id
    )
    expect(build_payload[:can_stronger_model]).to eq(false)
  end

  it "marks consultations older than 7 days as stale with a warning" do
    create_completed_consultation(created_at: 8.days.ago)
    payload = build_payload
    expect(payload[:consultation_stale]).to eq(true)
    expect(payload[:stale_warning]).to include("out of date")
  end

  it "does not mark fresh consultations as stale" do
    create_completed_consultation(created_at: 2.days.ago)
    payload = build_payload
    expect(payload[:consultation_stale]).to eq(false)
    expect(payload[:stale_warning]).to be_nil
  end

  it "serializes summary for the check-in match list, not short quote" do
    batch.update!(
      extraction_status: "completed",
      extractions: {
        "version" => 1,
        "items" => [
          {
            "id" => "match-1",
            "kind" => "kudos",
            "confidence" => 0.9,
            "include" => true,
            "summary" => "This is a story about when Pat shipped early.",
            "short_quote" => "shipped early",
            "full_quote" => "Pat shipped early and crushed the launch.",
            "suggested_rateable_type" => "Assignment",
            "suggested_rateable_id" => assignment.id
          }
        ]
      }
    )

    match = build_payload[:object_matches].first
    expect(match[:summary]).to eq("This is a story about when Pat shipped early.")
    expect(match).not_to have_key(:short_quote)
  end
end
