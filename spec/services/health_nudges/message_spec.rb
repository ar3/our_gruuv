# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthNudges::Message do
  let(:company) { create(:organization, :company) }
  let(:manager_teammate) { create(:teammate, :assigned_employee, organization: company) }
  let(:stats) do
    {
      total_employees: 4,
      healthy_count: 2,
      warning_count: 1,
      needs_attention_count: 1
    }
  end

  it "builds goals health copy with an absolute dashboard link and Slack button" do
    message = described_class.new(
      health_object: "goals_health",
      organization: company,
      manager_teammate: manager_teammate,
      spotlight_stats: stats
    )

    expect(message.body_mrkdwn).to include("Goals Health check-in")
    expect(message.body_mrkdwn).to include("Goal Confidence")
    expect(message.body_mrkdwn).to include("Fresh Goal Confidence check-ins")
    expect(message.dashboard_url).to start_with("http")
    expect(message.dashboard_url).to include("/goals_health")
    expect(message.body_mrkdwn).to include("<#{message.dashboard_url}|")

    button = message.slack_blocks.find { |block| block[:type] == "actions" }
                    .fetch(:elements).first
    expect(button[:type]).to eq("button")
    expect(button[:url]).to eq(message.dashboard_url)
    expect(button[:text][:text]).to eq("Open Goals Health for your team")
  end

  it "calls Protect Flow Overall Health in nudge copy" do
    message = described_class.new(
      health_object: "protect_flow",
      organization: company,
      manager_teammate: manager_teammate,
      spotlight_stats: {
        total_employees: 3,
        healthy_count: 1,
        needs_attention_count: 2,
        current_unhealthy_vectors: 4,
        improved_vector_count: 1,
        week_start: "2026-08-18"
      }
    )

    expect(message.body_mrkdwn).to include("Overall Health check-in")
    expect(message.body_mrkdwn).to include("Overall Health for your direct reports")
    expect(message.body_mrkdwn).to include("Open Overall Health for your team")
    expect(message.body_mrkdwn).not_to include("Protect Flow")
    expect(message.dashboard_url).to include("/protect_flow")
  end
end
