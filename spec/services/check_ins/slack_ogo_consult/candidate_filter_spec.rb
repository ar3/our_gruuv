# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckIns::SlackOgoConsult::CandidateFilter do
  let(:organization) { create(:organization, :company) }
  let(:creator) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:subject_teammate) { create(:company_teammate, :assigned_employee, organization: organization) }
  let(:assignment) { create(:assignment, company: organization) }
  let(:other_assignment) { create(:assignment, company: organization) }
  let(:search) do
    create(
      :possible_observation_slack_search,
      :completed,
      organization: organization,
      creator_company_teammate: creator,
      subject_company_teammate: subject_teammate
    )
  end
  let(:batch) { search.message_batches.first }

  before do
    batch.update!(
      extraction_status: "completed",
      extractions: {
        "version" => 1,
        "items" => [
          {
            "id" => "a",
            "confidence" => 0.9,
            "suggested_rateable_type" => "Assignment",
            "suggested_rateable_id" => assignment.id,
            "quote" => "match",
            "short_quote" => "match"
          },
          {
            "id" => "b",
            "confidence" => 0.85,
            "suggested_rateable_type" => "Assignment",
            "suggested_rateable_id" => other_assignment.id,
            "quote" => "other",
            "short_quote" => "other"
          },
          {
            "id" => "c",
            "confidence" => 0.7,
            "suggested_rateable_type" => "Assignment",
            "suggested_rateable_id" => assignment.id,
            "quote" => "low",
            "short_quote" => "low"
          }
        ]
      }
    )
  end

  it "keeps object matches at or above 80% and counts other high-confidence hits" do
    result = described_class.call(
      search: search,
      rateable_type: "Assignment",
      rateable_id: assignment.id
    )

    expect(result[:object_matches].map { |m| m.item[:id] }).to eq(["a"])
    expect(result[:other_matches].map { |m| m.item[:id] }).to eq(["b"])
  end

  it "excludes candidates already promoted to an observation" do
    items = batch.extraction_items.map(&:to_h).map(&:stringify_keys)
    items.find { |i| i["id"] == "a" }["observation_id"] = 999
    batch.replace_extraction_items!(items)

    result = described_class.call(
      search: search,
      rateable_type: "Assignment",
      rateable_id: assignment.id
    )

    expect(result[:object_matches]).to be_empty
    expect(result[:other_matches].map { |m| m.item[:id] }).to eq(["b"])
  end
end
