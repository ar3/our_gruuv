# frozen_string_literal: true

require "rails_helper"

RSpec.describe CytoscapeGraphLayout do
  let(:organization) { create(:organization) }

  describe "validations" do
    it "accepts a hash of node coordinates" do
      layout = described_class.new(
        layoutable: organization,
        graph_kind: "full_network",
        positions: { "a1" => { "x" => 10.5, "y" => 20.0 } },
        node_fingerprint: "abc"
      )

      expect(layout).to be_valid
    end

    it "rejects invalid position shapes" do
      layout = described_class.new(
        layoutable: organization,
        graph_kind: "full_network",
        positions: { "a1" => { "x" => "nope" } }
      )

      expect(layout).not_to be_valid
    end
  end

  describe ".upsert_for!" do
    it "creates and updates layouts for the same layoutable" do
      described_class.upsert_for!(
        layoutable: organization,
        graph_kind: "full_network",
        positions: { "a1" => { "x" => 1, "y" => 2 } },
        node_fingerprint: "one"
      )

      described_class.upsert_for!(
        layoutable: organization,
        graph_kind: "full_network",
        positions: { "a1" => { "x" => 3, "y" => 4 } },
        node_fingerprint: "two"
      )

      layout = described_class.for_layoutable(organization, graph_kind: "full_network")
      expect(layout.positions).to eq("a1" => { "x" => 3.0, "y" => 4.0 })
      expect(layout.node_fingerprint).to eq("two")
    end
  end
end
