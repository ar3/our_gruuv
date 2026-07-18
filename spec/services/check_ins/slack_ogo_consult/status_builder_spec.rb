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
end
