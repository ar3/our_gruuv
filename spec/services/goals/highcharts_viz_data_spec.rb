# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::HighchartsVizData, type: :service do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:parent_a) do
    create(:goal, creator: teammate, owner: teammate, company: organization, title: "Parent A", started_at: 1.week.ago)
  end
  let(:parent_b) do
    create(:goal, creator: teammate, owner: teammate, company: organization, title: "Parent B", started_at: 1.week.ago)
  end
  let(:child) do
    create(:goal, creator: teammate, owner: teammate, company: organization, title: "Shared Child", started_at: 1.week.ago)
  end

  before do
    create(:goal_link, parent: parent_a, child: child)
    create(:goal_link, parent: parent_b, child: child)
  end

  let(:soft_statuses) do
    {
      parent_a.id => { label: "On Track", stroke: "#198754", path: "/a", kind: :on_track },
      parent_b.id => { label: "Draft", stroke: "#6c757d", path: "/b", kind: :draft },
      child.id => { label: "Off Track", stroke: "#dc3545", path: "/c#check-in", kind: :on_track, status: :red }
    }
  end

  let(:data) do
    described_class.new(
      goals: [parent_a, parent_b, child],
      organization: organization,
      soft_statuses: soft_statuses
    )
  end

  it "builds networkgraph with unique nodes and multi-parent links" do
    payload = data.payload_for("hc-networkgraph")
    expect(payload[:series_type]).to eq("networkgraph")
    expect(payload[:nodes].map { |n| n[:id] }).to contain_exactly("g#{parent_a.id}", "g#{parent_b.id}", "g#{child.id}")
    expect(payload[:links].size).to eq(2)
  end

  it "duplicates multi-parent children in treegraph and marks them" do
    payload = data.payload_for("hc-treegraph")
    child_nodes = payload[:nodes].select { |n| n[:name].include?("Shared Child") }
    expect(child_nodes.size).to eq(2)
    expect(child_nodes.count { |n| n[:duplicated] }).to eq(1)
    expect(child_nodes.any? { |n| n[:name].include?("⧉") }).to be(true)
    expect(payload[:nodes].any? { |n| n[:subtitle].to_s.include?("multi-parent (duplicated)") }).to be(true)
  end

  it "builds sankey rows with soft-colored nodes" do
    payload = data.payload_for("hc-sankey-vertical")
    expect(payload[:series_type]).to eq("sankey")
    expect(payload[:inverted]).to be(true)
    expect(payload[:data].size).to eq(2)
    child_node = payload[:nodes].find { |n| n[:id] == "g#{child.id}" }
    expect(child_node[:color]).to eq("#dc3545")
    expect(child_node[:name]).to include("⧉")
  end

  it "builds organization payload with inverted flag for vertical" do
    payload = data.payload_for("hc-organization-vertical")
    expect(payload[:series_type]).to eq("organization")
    expect(payload[:inverted]).to be(true)
    expect(payload[:links].size).to eq(2)
  end
end
