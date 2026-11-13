# frozen_string_literal: true

require "rails_helper"

RSpec.describe ProtectFlow::OpportunitySentence do
  let(:company) { create(:organization, :company) }
  let(:viewer) { create(:company_teammate, organization: company) }
  let(:teammate) { create(:company_teammate, organization: company) }
  let(:reference_date) { Date.new(2026, 11, 12) }

  def call_sentence(**overrides)
    described_class.call(
      **{
        organization: company,
        teammate: teammate,
        viewer: viewer,
        category: EngagementHealth::CATEGORY_OGO_RECEIVED,
        short_title: "OGOs Received",
        status: EngagementHealth::WARNING,
        role: :attention,
        items: [],
        item_links: [],
        reference_date: reference_date
      }.merge(overrides)
    )
  end

  it "links OGOs Received attention to the values feedback-request accept flow" do
    sentence = call_sentence

    expect(sentence[:before]).to eq("Haven't received an OGO in a while — ")
    expect(sentence[:link_text]).to eq("send a feedback request")
    expect(sentence[:link_path]).to include("accept_feedback_offer")
    expect(sentence[:link_path]).to include("offer_key=values")
    expect(sentence[:link_method]).to eq(:post)
    expect(sentence[:after]).to eq(".")
  end

  it "uses request-about-yourself when the viewer is the subject" do
    sentence = call_sentence(viewer: teammate)

    expect(sentence[:link_text]).to eq("request feedback about yourself")
    expect(sentence[:link_path]).to include("feedback_requests/new")
    expect(sentence[:link_method]).to be_nil
  end

  it "builds a linked clarity warning sentence for a named item" do
    item = EngagementHealthStatus.create!(
      teammate: teammate,
      organization: company,
      level: "item",
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      entity_type: "Assignment",
      entity_id: 42,
      status: EngagementHealth::WARNING,
      inputs: { "name" => "Support Desk", "last_event_at" => "2026-09-01" },
      computed_at: Time.current
    )

    sentence = call_sentence(
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      short_title: "Clarity Check-ins",
      status: EngagementHealth::WARNING,
      items: [item]
    )

    expect(sentence[:before]).to eq("Clarity is getting stale — ")
    expect(sentence[:link_text]).to eq("check in on Support Desk")
    expect(sentence[:link_path]).to include("/assignments/42")
    expect(sentence[:after]).to include("last finalized check-in on this was Sep 1, 2026")
  end

  it "builds a Needs Attention clarity sentence without repeating the status" do
    item = EngagementHealthStatus.create!(
      teammate: teammate,
      organization: company,
      level: "item",
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      entity_type: "Assignment",
      entity_id: 42,
      status: EngagementHealth::NEEDS_ATTENTION,
      inputs: { "name" => "Be Kind", "last_event_at" => "2026-08-15" },
      computed_at: Time.current
    )

    sentence = call_sentence(
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      short_title: "Clarity Check-ins",
      status: EngagementHealth::NEEDS_ATTENTION,
      items: [item]
    )

    expect(sentence[:before]).to eq("")
    expect(sentence[:link_text]).to eq("Check in on the Assignment Be Kind")
    expect(sentence[:after]).to eq(" — last finalized check-in on this was Aug 15, 2026.")
    expect(sentence[:link_text]).not_to include("needs attention")
  end

  it "links Needs Attention milestones without a completed calibration to calibration" do
    sentence = call_sentence(
      category: EngagementHealth::CATEGORY_MILESTONES,
      short_title: "Milestones",
      status: EngagementHealth::NEEDS_ATTENTION,
      items: []
    )

    expect(sentence[:link_text]).to eq("Complete the initial Ability Milestone calibration")
    expect(sentence[:link_path]).to include("ability_milestone_calibration")
    expect(sentence[:before]).to eq("")
  end

  it "builds a linked steady clarity sentence with a future by-date" do
    item = EngagementHealthStatus.create!(
      teammate: teammate,
      organization: company,
      level: "item",
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      entity_type: "Assignment",
      entity_id: 42,
      status: EngagementHealth::HEALTHY,
      inputs: {
        "name" => "Support Desk",
        "healthy_until_at" => "2026-11-20"
      },
      computed_at: Time.current
    )

    sentence = call_sentence(
      category: EngagementHealth::CATEGORY_REQUIRED_CLARITY,
      short_title: "Clarity Check-ins",
      status: EngagementHealth::HEALTHY,
      role: :clear,
      items: [item]
    )

    expect(sentence[:before]).to eq("Clarity Check-ins is steady — consider ")
    expect(sentence[:link_text]).to eq("checking in on Support Desk")
    expect(sentence[:after]).to eq(" by Nov 21, 2026.")
  end
end
