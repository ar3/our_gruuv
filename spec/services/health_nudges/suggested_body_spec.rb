# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthNudges::SuggestedBody do
  let(:company) { create(:organization, :company) }
  let(:manager) { create(:company_teammate, organization: company) }

  it "includes greeting, summary, closing, and per-employee focus lines under the Slack budget" do
    message = HealthNudges::Message.new(
      health_object: "protect_flow",
      organization: company,
      manager_teammate: manager,
      spotlight_stats: {
        total_employees: 1,
        healthy_count: 0,
        needs_attention_count: 1,
        current_steady_signals: 4,
        improved_signal_count: 0,
        total_signal_count: 5
      }
    )
    people = [
      {
        name: "Alex",
        worst_status: EngagementHealth::NEEDS_ATTENTION,
        attention_items: [
          {
            short_title: "Clarity Check-ins",
            status_label: "Needs Attention",
            category: EngagementHealth::CATEGORY_REQUIRED_CLARITY
          }
        ]
      }
    ]

    body = described_class.call(message: message, people: people)
    expect(body).to include("Hi ")
    expect(body).to include("Alex: focus on Clarity Check-ins")
    expect(body.length).to be <= described_class::MAX_CHARS
    expect(body).not_to include("http")
  end
end
