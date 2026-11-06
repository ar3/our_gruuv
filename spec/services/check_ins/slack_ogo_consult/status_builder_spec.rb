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
      helpers: helpers,
      viewer: viewer
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

  it "serializes shared moment-row HTML for the check-in match list" do
    create(
      :slack_possible_observation,
      organization: organization,
      subject_company_teammate: subject_teammate,
      discoverer_company_teammate_ids: [viewer.id],
      message_ts: 2.days.ago.to_f.to_s,
      payload: {
        "kind" => "kudos",
        "confidence" => 0.9,
        "summary" => "This is a story about when Pat shipped early.",
        "short_quote" => "shipped early",
        "full_quote" => "Pat shipped early and crushed the launch.",
        "suggested_rateable_type" => "Assignment",
        "suggested_rateable_id" => assignment.id,
        "suggested_rateable_name" => assignment.title,
        "suggested_rating" => "strongly_agree",
        "permalink" => "https://example.slack.com/p1"
      }
    )

    match = build_payload[:object_matches].first
    expect(match[:html]).to include("This is a story about when Pat shipped early.")
    expect(match[:html]).to include("Assignment ·")
    expect(match[:html]).to include("bg-success")
    expect(match[:html]).to include("Open in Slack")
    expect(match[:html]).not_to include("Promote to OGO")
    expect(match[:html]).not_to include("Dismiss: this is not OGO-worthy")
    expect(match[:slack_possible_observation_id]).to be_present
  end
end
