# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SlackOgoConsult::RecentSearchFinder do
  let(:organization) { create(:organization, :company) }
  let(:viewer) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
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

  def create_consultation(created_at:)
    consultation = OgConsultation.create!(
      subject: batch,
      organization: organization,
      kind: OgConsultation::KIND_OGO_SEARCH_SLACK,
      status: "completed",
      billable: true,
      triggered_by_teammate: viewer,
      model_id: "test-model",
      prompt_version: "1",
      units_total: 1,
      units_completed: 1,
      started_at: created_at,
      completed_at: created_at
    )
    consultation.update_columns(created_at: created_at, updated_at: created_at)
    consultation
  end

  it "returns the search when the viewer consulted a batch within 7 days" do
    create_consultation(created_at: 2.days.ago)
    expect(described_class.call(viewer: viewer, subject_teammate: subject_teammate)).to eq(search)
  end

  it "still returns the search when the consultation is older than 7 days" do
    create_consultation(created_at: 8.days.ago)
    expect(described_class.call(viewer: viewer, subject_teammate: subject_teammate)).to eq(search)
  end
end
