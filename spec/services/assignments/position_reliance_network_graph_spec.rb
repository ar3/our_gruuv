# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Assignments::PositionRelianceNetworkGraph do
  let(:organization) { create(:organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:required_assignment) { create(:assignment, company: organization, title: 'Required Role') }
  let(:suggested_assignment) { create(:assignment, company: organization, title: 'Suggested Role') }
  let(:external_upstream) { create(:assignment, company: organization, title: 'External Upstream') }
  let(:external_downstream) { create(:assignment, company: organization, title: 'External Downstream') }
  let(:far_upstream) { create(:assignment, company: organization, title: 'Far Upstream') }

  subject(:network) { described_class.new(position: position, organization: organization) }

  before do
    create(:position_assignment, position: position, assignment: required_assignment, assignment_type: 'required')
    create(:position_assignment, position: position, assignment: suggested_assignment, assignment_type: 'suggested')
  end

  describe '#show_graph?' do
    it 'is true when the position has required or suggested assignments' do
      expect(network.show_graph?).to be true
    end

    it 'is false when the position has no assignments' do
      other_level = create(:position_level, position_major_level: title.position_major_level, level: '9.9')
      empty_position = create(:position, title: title, position_level: other_level)
      empty_network = described_class.new(position: empty_position, organization: organization)

      expect(empty_network.show_graph?).to be false
    end
  end

  describe '#components' do
    it 'includes position assignments and one-hop neighbors only' do
      create(
        :assignment_supply_relationship,
        supplier_assignment: external_upstream,
        consumer_assignment: required_assignment
      )
      create(
        :assignment_supply_relationship,
        supplier_assignment: required_assignment,
        consumer_assignment: external_downstream
      )
      create(
        :assignment_supply_relationship,
        supplier_assignment: far_upstream,
        consumer_assignment: external_upstream
      )

      component = network.components.first
      expect(component.assignments.map(&:id)).to contain_exactly(
        required_assignment.id,
        suggested_assignment.id,
        external_upstream.id,
        external_downstream.id
      )
      expect(component.assignments.map(&:id)).not_to include(far_upstream.id)
    end

    it 'deduplicates a shared external neighbor linked from multiple position assignments' do
      shared = create(:assignment, company: organization, title: 'Shared External')
      create(
        :assignment_supply_relationship,
        supplier_assignment: shared,
        consumer_assignment: required_assignment
      )
      create(
        :assignment_supply_relationship,
        supplier_assignment: shared,
        consumer_assignment: suggested_assignment
      )

      component = network.components.first
      shared_nodes = component.elements.select do |element|
        element[:group] == 'nodes' && element[:data][:id] == "a#{shared.id}"
      end

      expect(shared_nodes.size).to eq(1)
      expect(shared_nodes.first.dig(:data, :highlightTier)).to eq('external')

      edges = component.elements.select { |element| element[:group] == 'edges' }
      expect(edges.size).to eq(2)
    end

    it 'assigns highlight tiers for required, suggested, and external nodes' do
      create(
        :assignment_supply_relationship,
        supplier_assignment: external_upstream,
        consumer_assignment: required_assignment
      )

      component = network.components.first
      tiers_by_id = component.elements
        .select { |element| element[:group] == 'nodes' }
        .to_h { |element| [element[:data][:id], element[:data][:highlightTier]] }

      expect(tiers_by_id["a#{required_assignment.id}"]).to eq('required')
      expect(tiers_by_id["a#{suggested_assignment.id}"]).to eq('suggested')
      expect(tiers_by_id["a#{external_upstream.id}"]).to eq('external')
    end

    it 'returns position assignments with no edges when there are no supply links' do
      component = network.components.first
      expect(component.assignments.map(&:id)).to contain_exactly(
        required_assignment.id,
        suggested_assignment.id
      )
      expect(component.elements.count { |element| element[:group] == 'edges' }).to eq(0)
    end

    it 'excludes archived assignments from the graph' do
      archived = create(:assignment, company: organization, title: 'Archived', deleted_at: Time.current)
      create(
        :assignment_supply_relationship,
        supplier_assignment: archived,
        consumer_assignment: required_assignment
      )

      component = network.components.first
      expect(component.assignments.map(&:id)).not_to include(archived.id)
    end
  end
end
