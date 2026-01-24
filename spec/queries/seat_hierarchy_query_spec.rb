require 'rails_helper'

RSpec.describe SeatHierarchyQuery do
  let(:organization) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, organization: organization, position_major_level: position_major_level) }
  
  describe '#call' do
    context 'with no seats' do
      it 'returns empty array' do
        query = SeatHierarchyQuery.new(organization: organization)
        expect(query.call).to eq([])
      end
    end

    context 'with seats but no hierarchy' do
      let!(:seat1) { create(:seat, title: title, seat_needed_by: Date.current + 1.month) }
      let!(:seat2) { create(:seat, title: title, seat_needed_by: Date.current + 2.months) }

      it 'returns all seats as root nodes' do
        query = SeatHierarchyQuery.new(organization: organization)
        results = query.call
        
        expect(results.count).to eq(2)
        expect(results.map { |r| r[:seat] }).to include(seat1, seat2)
        results.each do |node|
          expect(node[:children]).to eq([])
          expect(node[:direct_reports_count]).to eq(0)
          expect(node[:total_reports_count]).to eq(0)
        end
      end
    end

    context 'with simple hierarchy' do
      let!(:root_seat) { create(:seat, title: title, seat_needed_by: Date.current + 1.month) }
      let!(:child_seat) { create(:seat, title: title, seat_needed_by: Date.current + 2.months, reports_to_seat: root_seat) }
      let!(:grandchild_seat) { create(:seat, title: title, seat_needed_by: Date.current + 3.months, reports_to_seat: child_seat) }

      it 'builds correct hierarchy tree' do
        query = SeatHierarchyQuery.new(organization: organization)
        results = query.call
        
        expect(results.count).to eq(1)
        root_node = results.first
        
        expect(root_node[:seat]).to eq(root_seat)
        expect(root_node[:direct_reports_count]).to eq(1)
        expect(root_node[:total_reports_count]).to eq(2)
        
        child_node = root_node[:children].first
        expect(child_node[:seat]).to eq(child_seat)
        expect(child_node[:direct_reports_count]).to eq(1)
        expect(child_node[:total_reports_count]).to eq(1)
        
        grandchild_node = child_node[:children].first
        expect(grandchild_node[:seat]).to eq(grandchild_seat)
        expect(grandchild_node[:direct_reports_count]).to eq(0)
        expect(grandchild_node[:total_reports_count]).to eq(0)
      end
    end

    context 'with multiple root seats' do
      let!(:root1) { create(:seat, title: title, seat_needed_by: Date.current + 1.month) }
      let!(:root2) { create(:seat, title: title, seat_needed_by: Date.current + 2.months) }
      let!(:child1) { create(:seat, title: title, seat_needed_by: Date.current + 3.months, reports_to_seat: root1) }
      let!(:child2) { create(:seat, title: title, seat_needed_by: Date.current + 4.months, reports_to_seat: root2) }

      it 'returns multiple root nodes' do
        query = SeatHierarchyQuery.new(organization: organization)
        results = query.call
        
        expect(results.count).to eq(2)
        root_seats = results.map { |r| r[:seat] }
        expect(root_seats).to include(root1, root2)
        
        results.each do |root_node|
          expect(root_node[:direct_reports_count]).to eq(1)
          expect(root_node[:total_reports_count]).to eq(1)
        end
      end
    end

    context 'with seats having multiple direct reports' do
      let!(:root_seat) { create(:seat, title: title, seat_needed_by: Date.current + 1.month) }
      let!(:child1) { create(:seat, title: title, seat_needed_by: Date.current + 2.months, reports_to_seat: root_seat) }
      let!(:child2) { create(:seat, title: title, seat_needed_by: Date.current + 3.months, reports_to_seat: root_seat) }
      let!(:child3) { create(:seat, title: title, seat_needed_by: Date.current + 4.months, reports_to_seat: root_seat) }

      it 'calculates correct counts' do
        query = SeatHierarchyQuery.new(organization: organization)
        results = query.call
        
        root_node = results.first
        expect(root_node[:direct_reports_count]).to eq(3)
        expect(root_node[:total_reports_count]).to eq(3)
        expect(root_node[:children].count).to eq(3)
      end
    end
  end
end

