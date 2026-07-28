# frozen_string_literal: true

require "rails_helper"

RSpec.describe AgentTools::Registry do
  it "exposes stable write tool names" do
    expect(described_class.write_tool?("create_draft_observation")).to be(true)
    expect(described_class.write_tool?("set_current_week_goal_confidence")).to be(true)
    expect(described_class.write_tool?("list_teammates")).to be(false)
  end

  it "raises for unknown tools" do
    expect { described_class.fetch("not_a_tool") }.to raise_error(AgentTools::UnknownTool)
  end

  it "exposes JSON input schemas for every registered tool" do
    described_class.tool_names.each do |name|
      expect(described_class.input_schema_for(name)).to be_a(Hash)
      expect(described_class.description_for(name)).to be_present
    end
  end
end
