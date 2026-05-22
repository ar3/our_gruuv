# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assignments::SupplyGraphElements do
  let(:organization) { create(:organization, :company) }
  let(:supplier) { create(:assignment, company: organization, title: 'Supplier') }
  let(:consumer) { create(:assignment, company: organization, title: 'Consumer') }
  let(:relationship) do
    create(:assignment_supply_relationship, supplier_assignment: supplier, consumer_assignment: consumer)
  end
  let(:assignments) { [supplier, consumer] }
  let(:relationships) { [relationship] }

  describe '.cytoscape_elements' do
    it 'builds nodes and directed edges' do
      elements = described_class.cytoscape_elements(
        assignments,
        relationships,
        organization: organization,
        current_assignment_id: supplier.id
      )

      node_ids = elements.select { |e| e[:group] == 'nodes' }.map { |e| e[:data][:id] }
      expect(node_ids).to contain_exactly("a#{supplier.id}", "a#{consumer.id}")

      supplier_node = elements.find { |e| e[:data][:id] == "a#{supplier.id}" }
      expect(supplier_node[:data][:isCurrent]).to be true

      edge = elements.find { |e| e[:group] == 'edges' }
      expect(edge[:data][:source]).to eq("a#{supplier.id}")
      expect(edge[:data][:target]).to eq("a#{consumer.id}")
    end
  end

  describe '.highcharts_sankey_data' do
    it 'builds nodes and weighted supplier-to-consumer links' do
      data = described_class.highcharts_sankey_data(
        assignments,
        relationships,
        organization: organization
      )

      expect(data[:nodes].map { |n| n[:id] }).to contain_exactly(supplier.id.to_s, consumer.id.to_s)
      expect(data[:data]).to eq([[supplier.id.to_s, consumer.id.to_s, 1]])
      expect(data[:nodes].first).to include(:url)
    end
  end

  describe '.highcharts_network_graph_data' do
    it 'builds nodes and supplier-to-consumer links' do
      data = described_class.highcharts_network_graph_data(
        assignments,
        relationships,
        organization: organization
      )

      expect(data[:nodes].map { |n| n[:id] }).to contain_exactly(supplier.id.to_s, consumer.id.to_s)
      expect(data[:links]).to eq([[supplier.id.to_s, consumer.id.to_s]])
      expect(data[:nodes].first).to include(:url)
    end
  end

  describe '.g6_graph_data' do
    it 'builds G6 nodes and directed edges with navigation urls' do
      data = described_class.g6_graph_data(assignments, relationships, organization: organization)

      expect(data[:nodes].map { |n| n[:id] }).to contain_exactly(supplier.id.to_s, consumer.id.to_s)
      expect(data[:nodes].first[:data][:label]).to eq('Supplier')
      expect(data[:edges].first).to include(
        id: "e#{relationship.id}",
        source: supplier.id.to_s,
        target: consumer.id.to_s
      )
    end
  end

  describe '.vis_network_data' do
    it 'builds vis nodes and edges with navigation urls' do
      data = described_class.vis_network_data(assignments, relationships, organization: organization)

      expect(data[:nodes].map { |n| n[:id] }).to contain_exactly(supplier.id, consumer.id)
      expect(data[:edges].first).to include(from: supplier.id, to: consumer.id, arrows: 'to')
      expect(data[:nodes].first[:url]).to include(supplier.id.to_s)
    end
  end
end
