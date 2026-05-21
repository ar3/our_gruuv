# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assignments::AccountabilityFlowGraph do
  let(:organization) { create(:organization) }
  let(:assignment) { create(:assignment, company: organization, title: 'Center Assignment') }
  let(:upstream) { create(:assignment, company: organization, title: 'Upstream') }
  let(:downstream) { create(:assignment, company: organization, title: 'Downstream') }
  let(:scoped_assignment_ids) { organization.assignments.pluck(:id) }

  subject(:graph) do
    described_class.new(
      assignment: assignment,
      organization: organization,
      scoped_assignment_ids: scoped_assignment_ids
    )
  end

  describe '#has_supply_links?' do
    it 'is false when the assignment has no relationships' do
      expect(graph.has_supply_links?).to be false
    end

    it 'is true when the assignment supplies another assignment' do
      create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)

      expect(graph.has_supply_links?).to be true
    end

    it 'is true when the assignment consumes from another assignment' do
      create(:assignment_supply_relationship, supplier_assignment: upstream, consumer_assignment: assignment)

      expect(graph.has_supply_links?).to be true
    end
  end

  describe '#components' do
    it 'returns no components when there are no supply links' do
      expect(graph.components).to eq([])
    end

    it 'returns one connected component with nodes and directed edges' do
      create(:assignment_supply_relationship, supplier_assignment: upstream, consumer_assignment: assignment)
      create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)

      components = graph.components
      expect(components.size).to eq(1)

      component = components.first
      expect(component.assignments.map(&:id)).to contain_exactly(upstream.id, assignment.id, downstream.id)

      node_ids = component.elements.select { |element| element[:group] == 'nodes' }.map { |element| element[:data][:id] }
      expect(node_ids).to contain_exactly("a#{upstream.id}", "a#{assignment.id}", "a#{downstream.id}")

      current_nodes = component.elements.select { |element| element.dig(:data, :isCurrent) }
      expect(current_nodes.size).to eq(1)
      expect(current_nodes.first[:data][:id]).to eq("a#{assignment.id}")

      edges = component.elements.select { |element| element[:group] == 'edges' }
      expect(edges.map { |edge| [edge[:data][:source], edge[:data][:target]] }).to contain_exactly(
        ["a#{upstream.id}", "a#{assignment.id}"],
        ["a#{assignment.id}", "a#{downstream.id}"]
      )

      expect(component.root_node_ids).to eq(["a#{upstream.id}"])
    end

    it 'only includes assignments reachable within the scoped id set' do
      create(:assignment_supply_relationship, supplier_assignment: upstream, consumer_assignment: assignment)
      create(:assignment_supply_relationship, supplier_assignment: assignment, consumer_assignment: downstream)

      scoped_graph = described_class.new(
        assignment: assignment,
        organization: organization,
        scoped_assignment_ids: [assignment.id, downstream.id]
      )

      component = scoped_graph.components.first
      expect(component.assignments.map(&:id)).to contain_exactly(assignment.id, downstream.id)
    end
  end
end
