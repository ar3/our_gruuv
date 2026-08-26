# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthNudges::EmployeeThreadMessage do
  it "builds a section with status detail, profile image, and destination button" do
    message = described_class.new(
      entry: {
        name: "Alex",
        status: EngagementHealth::NEEDS_ATTENTION,
        status_label: "Needs Attention",
        status_emoji: ":red_circle:",
        detail: "Goal Confidence is stale.",
        profile_image_url: "https://example.com/alex.png",
        action_url: "https://example.com/goals",
        action_button_label: "Go to Alex's Goals Page"
      }
    )

    section = message.slack_blocks.first
    expect(section[:type]).to eq("section")
    expect(section[:text][:text]).to include("Alex")
    expect(section[:text][:text]).to include("Needs Attention")
    expect(section[:text][:text]).to include("Goal Confidence is stale.")
    expect(section[:accessory][:type]).to eq("image")
    expect(section[:accessory][:image_url]).to eq("https://example.com/alex.png")

    actions = message.slack_blocks.last
    expect(actions[:type]).to eq("actions")
    button = actions[:elements].first
    expect(button[:type]).to eq("button")
    expect(button[:url]).to eq("https://example.com/goals")
    expect(button[:text][:text]).to eq("Go to Alex's Goals Page")
  end
end
