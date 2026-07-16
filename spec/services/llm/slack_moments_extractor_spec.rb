# frozen_string_literal: true

require "rails_helper"

RSpec.describe Llm::SlackMomentsExtractor do
  let(:catalog) do
    {
      "Assignment" => { 11 => "Own launch" },
      "Ability" => {},
      "Aspiration" => {},
      "Goal" => { 22 => "Close Q3 deals" }
    }
  end

  def parse(json, context_catalog: catalog)
    described_class.new(
      chunk_text: "msg",
      subject_name: "Pat",
      context_text: "SUBJECT",
      context_catalog: context_catalog
    ).send(:parse_items, json)
  end

  it "weaves a rating suggestion into the summary and keeps structured fields" do
    result = parse(<<~JSON)
      {
        "items": [{
          "kind": "kudos",
          "summary": "This is a story about when Pat caused a successful launch by shipping early. And this made me feel proud.",
          "short_quote": "shipped early",
          "full_quote": "Pat shipped early and crushed the launch.",
          "speaker_label": "Alex",
          "recipient_label": "Pat",
          "channel_id": "C1",
          "ts": "1.0",
          "permalink": "https://example.slack.com/p1",
          "slack_user_id": "U1",
          "confidence": 0.91,
          "suggested_rateable_type": "Assignment",
          "suggested_rateable_id": 11,
          "suggested_rating": "strongly_agree",
          "suggested_goal_id": 22
        }]
      }
    JSON

    item = result["items"].first
    expect(item["confidence"]).to eq(0.91)
    expect(item["summary"]).to start_with("Suggested: Exceptional example of Assignment Own launch; linked to Goal Close Q3 deals.")
    expect(item["suggested_rateable_type"]).to eq("Assignment")
    expect(item["suggested_rateable_id"]).to eq(11)
    expect(item["suggested_rating"]).to eq("strongly_agree")
    expect(item["suggested_goal_id"]).to eq(22)
  end

  it "drops suggestion ids that are not in the catalog" do
    result = parse(<<~JSON)
      {
        "items": [{
          "kind": "kudos",
          "summary": "Story",
          "short_quote": "quote",
          "full_quote": "full",
          "confidence": 0.8,
          "suggested_rateable_type": "Assignment",
          "suggested_rateable_id": 999,
          "suggested_rating": "agree",
          "suggested_goal_id": 999
        }]
      }
    JSON

    item = result["items"].first
    expect(item["suggested_rateable_type"]).to be_nil
    expect(item["suggested_rateable_id"]).to be_nil
    expect(item["suggested_goal_id"]).to be_nil
    expect(item["suggested_rating"]).to eq("agree")
    expect(item["summary"]).to start_with("Suggested: Solid example.")
  end

  it "drops items below the minimum confidence threshold" do
    result = parse(<<~JSON)
      {
        "items": [{
          "kind": "kudos",
          "summary": "Weak",
          "short_quote": "nice",
          "full_quote": "nice job",
          "confidence": 0.4
        }]
      }
    JSON

    expect(result["items"]).to be_empty
  end
end
