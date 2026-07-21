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

  it "excludes candidates whose Slack moment falls outside the check-in window" do
    items = batch.extraction_items.map(&:to_h).map(&:stringify_keys)
    items.find { |i| i["id"] == "a" }["ts"] = 2.days.ago.to_f.to_s
    items << {
      "id" => "d",
      "confidence" => 0.95,
      "suggested_rateable_type" => "Assignment",
      "suggested_rateable_id" => assignment.id,
      "quote" => "old",
      "short_quote" => "old",
      "ts" => 40.days.ago.to_f.to_s
    }
    batch.replace_extraction_items!(items)

    result = described_class.call(
      search: search,
      rateable_type: "Assignment",
      rateable_id: assignment.id,
      since: 10.days.ago,
      until_time: Time.current
    )

    expect(result[:object_matches].map { |m| m.item[:id] }).to eq(["a"])
  end

  it "keeps candidates without a timestamp when a window is given" do
    result = described_class.call(
      search: search,
      rateable_type: "Assignment",
      rateable_id: assignment.id,
      since: 10.days.ago,
      until_time: Time.current
    )

    expect(result[:object_matches].map { |m| m.item[:id] }).to eq(["a"])
  end

  it "excludes dismissed candidates" do
    items = batch.extraction_items.map(&:to_h).map(&:stringify_keys)
    items.find { |i| i["id"] == "a" }["dismissed_at"] = Time.current.iso8601
    batch.replace_extraction_items!(items)

    result = described_class.call(
      search: search,
      rateable_type: "Assignment",
      rateable_id: assignment.id
    )

    expect(result[:object_matches]).to be_empty
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
