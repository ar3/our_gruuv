# frozen_string_literal: true

require "rails_helper"

RSpec.describe Titles::PathNeighborhoodGraph do
  let(:organization) { create(:organization) }
  let(:major_level) { create(:position_major_level) }
  let(:title) { create(:title, company: organization, position_major_level: major_level, external_title: "Engineer") }
  let(:next_title) { create(:title, company: organization, position_major_level: major_level, external_title: "Manager") }

  it "builds cytoscape elements for outbound neighbors" do
    create(:title_path, from_title: title, to_title: next_title, path_type: "switch_to_people_management")
    graph = described_class.new(title: title, organization: organization)

    expect(graph.show_graph?).to be(true)
    nodes = graph.elements.select { |e| e[:group] == "nodes" }
    ids = nodes.map { |e| e.dig(:data, :id) }
    expect(ids).to include("title-#{title.id}", "title-#{next_title.id}")
    expect(nodes.map { |e| e.dig(:data, :label) }).to include(next_title.title_including_level)
  end
end
