# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::ParseAskOgResponse do
  it "keeps only write tools and caps at two actions" do
    raw = {
      answer: "Here is help",
      proposed_actions: [
        { tool: "create_draft_observation", label: "Draft OGO", summary: "Make draft", args: { observee_path: "/organizations/1/company_teammates/2/internal" } },
        { tool: "list_teammates", label: "Nope", args: {} },
        { tool: "set_current_week_goal_confidence", label: "Check in", summary: "Set confidence", args: { goal_path: "/organizations/1/goals/3", confidence_percentage: 50 } },
        { tool: "create_draft_observation", label: "Another", args: { observee_path: "/organizations/1/company_teammates/4/internal" } }
      ]
    }.to_json

    parsed = described_class.call(raw)
    expect(parsed[:answer]).to eq("Here is help")
    expect(parsed[:proposed_actions].size).to eq(2)
    expect(parsed[:proposed_actions].map { |a| a["tool"] }).to eq(
      %w[create_draft_observation set_current_week_goal_confidence]
    )
  end
end
