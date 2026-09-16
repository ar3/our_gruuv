# frozen_string_literal: true

require "rails_helper"

RSpec.describe Titles::PathNeighborhoodGraph do
  let(:organization) { create(:organization) }
  let(:major_level) { create(:position_major_level, major_level: 2) }
  let(:next_major_level) { create(:position_major_level, major_level: 3, set_name: "Next-#{SecureRandom.hex(4)}") }
  let(:title) { create(:title, company: organization, position_major_level: major_level, external_title: "Engineer") }
  let(:next_title) { create(:title, company: organization, position_major_level: next_major_level, external_title: "Manager") }

  it "builds cytoscape elements for outbound neighbors" do
    create(:title_path, from_title: title, to_title: next_title, path_type: "switch_to_people_management")
    graph = described_class.new(title: title, organization: organization)

    expect(graph.show_graph?).to be(true)
    nodes = graph.elements.select { |e| e[:group] == "nodes" }
    ids = nodes.map { |e| e.dig(:data, :id) }
    expect(ids).to include("title-#{title.id}", "title-#{next_title.id}")
    expect(nodes.map { |e| e.dig(:data, :label) }).to include(next_title.title_including_level)
  end

  it "places neighborhood nodes in major-level columns like the insights graph" do
    create(:title_path, from_title: title, to_title: next_title, path_type: "natural_progression")
    graph = described_class.new(title: title, organization: organization)

    current_node = graph.elements.find { |e| e.dig(:data, :id) == "title-#{title.id}" }
    next_node = graph.elements.find { |e| e.dig(:data, :id) == "title-#{next_title.id}" }

    expect(current_node[:position][:x]).to eq(Titles::PathGraphLayout::COLUMN_WIDTH)
    expect(next_node[:position][:x]).to eq(Titles::PathGraphLayout::COLUMN_WIDTH * 2)
    expect(current_node.dig(:data, :majorLevel)).to eq(2)
    expect(next_node.dig(:data, :majorLevel)).to eq(3)
    expect(current_node.dig(:data, :highlightTier)).to eq("required")
  end
end
