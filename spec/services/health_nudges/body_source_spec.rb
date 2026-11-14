# frozen_string_literal: true

require "rails_helper"

RSpec.describe HealthNudges::BodySource do
  describe ".resolve" do
    it "detects exact suggested and og_consulted matches" do
      expect(described_class.resolve(sent: "A", suggested: "A", og_consulted: "B", base: "suggested")).to eq("suggested")
      expect(described_class.resolve(sent: "B", suggested: "A", og_consulted: "B", base: "og_consulted")).to eq("og_consulted")
    end

    it "classifies edits relative to the active base" do
      expect(described_class.resolve(sent: "C", suggested: "A", og_consulted: "B", base: "suggested")).to eq("custom_from_suggested")
      expect(described_class.resolve(sent: "C", suggested: "A", og_consulted: "B", base: "og_consulted")).to eq("custom_from_og_consulted")
    end
  end
end
