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
          "target_is_subject": true,
          "suggested_rateable_type": "Assignment",
          "suggested_rateable_id": 11,
          "suggested_rating": "strongly_agree",
          "association_reason": "The message directly describes ownership of the launch outcome.",
          "rating_reason": "Shipping early materially exceeded the expected outcome.",
          "suggested_goal_id": 22
        }]
      }
    JSON

    item = result["items"].first
    expect(item["confidence"]).to eq(0.91)
    expect(item["summary"]).to start_with("This is a story about")
    expect(item["quote"]).to start_with(
      "OG is suggesting: Exceptional example of the Assignment, Own launch."
    )
    expect(item["quote"]).to include(
      "OG thought it was an example of Own launch because The message directly describes ownership"
    )
    expect(item["quote"]).to include(
      "OG thought it was a Exceptional example because Shipping early materially exceeded"
    )
    expect(item["suggested_rateable_type"]).to eq("Assignment")
    expect(item["suggested_rateable_id"]).to eq(11)
    expect(item["suggested_rating"]).to eq("strongly_agree")
    expect(item["suggested_goal_id"]).to eq(22)
    expect(item["kind"]).to eq("kudos")
  end

  it "sets kind to feedback for Mis-aligned or Concerning ratings" do
    result = parse(<<~JSON)
      {
        "items": [{
          "kind": "kudos",
          "summary": "This is a story about when Pat missed the launch.",
          "short_quote": "missed it",
          "full_quote": "Pat missed the launch deadline.",
          "speaker_label": "Alex",
          "recipient_label": "Pat",
          "channel_id": "C1",
          "ts": "1.0",
          "confidence": 0.8,
          "target_is_subject": true,
          "suggested_rateable_type": "Assignment",
          "suggested_rateable_id": 11,
          "suggested_rating": "strongly_disagree",
          "association_reason": "It relates to the assignment.",
          "rating_reason": "It fell short of expectations."
        }]
      }
    JSON

    expect(result["items"].first["kind"]).to eq("feedback")
  end

  it "drops suggestion ids that are not in the catalog" do
    result = parse(<<~JSON)
      {
        "items": [{
          "kind": "kudos",
          "summary": "Story",
          "short_quote": "quote",
          "full_quote": "full",
          "recipient_label": "Pat",
          "confidence": 0.8,
          "target_is_subject": true,
          "suggested_rateable_type": "Assignment",
          "suggested_rateable_id": 999,
          "suggested_rating": "agree",
          "association_reason": "It relates to the assignment.",
          "rating_reason": "It met expectations.",
          "suggested_goal_id": 999
        }]
      }
    JSON

    expect(result["items"]).to be_empty
  end

  it "drops items below the minimum confidence threshold" do
    result = parse(<<~JSON)
      {
        "items": [{
          "kind": "kudos",
          "summary": "Weak",
          "short_quote": "nice",
          "full_quote": "nice job",
          "recipient_label": "Pat",
          "confidence": 0.4,
          "target_is_subject": true,
          "suggested_rateable_type": "Assignment",
          "suggested_rateable_id": 11,
          "suggested_rating": "agree",
          "association_reason": "It relates to the assignment.",
          "rating_reason": "It met expectations."
        }]
      }
    JSON

    expect(result["items"]).to be_empty
  end

  it "keeps items at the 50% confidence floor" do
    result = parse(<<~JSON)
      {
        "items": [{
          "kind": "kudos",
          "summary": "Borderline but returnable",
          "short_quote": "nice summary",
          "full_quote": "nice summary, thanks",
          "recipient_label": "Pat",
          "confidence": 0.5,
          "target_is_subject": true,
          "suggested_rateable_type": "Assignment",
          "suggested_rateable_id": 11,
          "suggested_rating": "agree",
          "association_reason": "It relates to the assignment.",
          "rating_reason": "It met expectations."
        }]
      }
    JSON

    expect(result["items"].size).to eq(1)
    expect(result["items"].first["confidence"]).to eq(0.5)
  end

  it "drops moments whose recipient is not the searched teammate" do
    result = parse(<<~JSON)
      {
        "items": [{
          "kind": "kudos",
          "summary": "This is about Alex.",
          "short_quote": "Alex crushed it",
          "full_quote": "Alex crushed the launch.",
          "recipient_label": "Alex",
          "confidence": 0.95,
          "target_is_subject": true,
          "suggested_rateable_type": "Assignment",
          "suggested_rateable_id": 11,
          "suggested_rating": "strongly_agree",
          "association_reason": "It relates to the assignment.",
          "rating_reason": "It exceeded expectations."
        }]
      }
    JSON

    expect(result["items"]).to be_empty
  end
end
