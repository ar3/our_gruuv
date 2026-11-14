# frozen_string_literal: true

require "rails_helper"

RSpec.describe Assistant::MaapSuggestionFocus do
  it "normalizes known focuses and rejects others" do
    expect(described_class.normalize("Seat")).to eq("seat")
    expect(described_class.normalize("assignment")).to eq("assignment")
    expect(described_class.normalize("abilities")).to eq("abilities")
    expect(described_class.normalize("team")).to be_nil
    expect(described_class.normalize("position")).to be_nil
  end

  it "maps tools by focus" do
    expect(described_class.tools_for("seat")).to eq(%w[create_seat_suggestion_bundle])
    expect(described_class.tools_for("assignment")).to eq(%w[create_assignment_suggestion_bundle])
    expect(described_class.tools_for("abilities")).to eq(%w[create_ability_suggestion_bundle])
  end

  it "reads focus from tool_context" do
    expect(described_class.from_tool_context("suggestion_focus" => "assignment")).to eq("assignment")
    expect(described_class.from_tool_context({})).to be_nil
  end
end
