# frozen_string_literal: true

require "rails_helper"

RSpec.describe Goals::NetworkGraphData do
  include Rails.application.routes.url_helpers

  let(:company) { create(:organization, :company) }
  let(:teammate) { create(:company_teammate, organization: company) }

  describe "#highcharts_organization_data" do
    it "returns empty nodes and links when goals are blank" do
      data = described_class.new(goals: [], goal_links: [], organization: company).highcharts_organization_data
      expect(data).to eq(nodes: [], links: [])
    end

    it "builds nodes and parent→child links with goal urls" do
      parent = create(:goal, creator: teammate, owner: teammate, company: company, title: "Parent Goal")
      child = create(:goal, creator: teammate, owner: teammate, company: company, title: "Child Goal")
      link = create(:goal_link, parent: parent, child: child)

      data = described_class.new(
        goals: [parent, child],
        goal_links: [link],
        organization: company
      ).highcharts_organization_data

      expect(data[:nodes]).to contain_exactly(
        hash_including(id: "g#{parent.id}", name: "Parent Goal", url: organization_goal_path(company, parent)),
        hash_including(id: "g#{child.id}", name: "Child Goal", url: organization_goal_path(company, child))
      )
      expect(data[:links]).to eq([{ from: "g#{parent.id}", to: "g#{child.id}" }])
    end
  end

  describe "#cytoscape_elements" do
    it "builds cytoscape nodes and edges" do
      parent = create(:goal, creator: teammate, owner: teammate, company: company, title: "Parent")
      child = create(:goal, creator: teammate, owner: teammate, company: company, title: "Child")
      link = create(:goal_link, parent: parent, child: child)

      elements = described_class.new(
        goals: [parent, child],
        goal_links: [link],
        organization: company
      ).cytoscape_elements

      nodes = elements.select { |e| e[:group] == "nodes" }
      edges = elements.select { |e| e[:group] == "edges" }

      expect(nodes.map { |n| n.dig(:data, :id) }).to contain_exactly("g#{parent.id}", "g#{child.id}")
      expect(edges).to contain_exactly(
        hash_including(
          group: "edges",
          data: hash_including(source: "g#{parent.id}", target: "g#{child.id}")
        )
      )
    end
  end

  describe "#cytoscape_root_node_ids" do
    it "returns goals that are not children in the link set" do
      parent = create(:goal, creator: teammate, owner: teammate, company: company)
      child = create(:goal, creator: teammate, owner: teammate, company: company)
      orphan = create(:goal, creator: teammate, owner: teammate, company: company)
      link = create(:goal_link, parent: parent, child: child)

      roots = described_class.new(
        goals: [parent, child, orphan],
        goal_links: [link],
        organization: company
      ).cytoscape_root_node_ids

      expect(roots).to contain_exactly("g#{parent.id}", "g#{orphan.id}")
    end
  end
end
