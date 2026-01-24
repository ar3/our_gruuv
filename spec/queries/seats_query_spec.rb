require 'rails_helper'

RSpec.describe SeatsQuery do
  let(:organization) { create(:organization, :company) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:title) { create(:title, organization: organization, position_major_level: position_major_level) }
  let(:title2) { create(:title, organization: organization, position_major_level: position_major_level, external_title: 'Product Manager') }
  
  let!(:draft_seat) { create(:seat, :draft, title: title, seat_needed_by: Date.current + 1.month) }
  let!(:open_seat) { create(:seat, :open, title: title, seat_needed_by: Date.current + 2.months) }
  let!(:filled_seat) { create(:seat, :filled, title: title2, seat_needed_by: Date.current + 3.months) }
  let!(:archived_seat) { create(:seat, :archived, title: title2, seat_needed_by: Date.current + 4.months) }
  
  let!(:parent_seat) { create(:seat, title: title, seat_needed_by: Date.current + 5.months) }
  let!(:child_seat) { create(:seat, title: title, seat_needed_by: Date.current + 6.months, reports_to_seat: parent_seat) }
  let!(:child_seat2) { create(:seat, title: title2, seat_needed_by: Date.current + 7.months, reports_to_seat: parent_seat) }

  describe '#call' do
    context 'with no filters' do
      it 'returns all seats for the organization' do
        query = SeatsQuery.new(organization, {})
        results = query.call
        
        expect(results.count).to eq(7)
        expect(results).to include(draft_seat, open_seat, filled_seat, archived_seat, parent_seat, child_seat, child_seat2)
      end
    end

    context 'with state filter' do
      it 'filters by single state' do
        query = SeatsQuery.new(organization, { state: ['open'] })
        results = query.call
        
        expect(results).to include(open_seat)
        expect(results).not_to include(draft_seat, filled_seat, archived_seat)
      end

      it 'filters by multiple states' do
        query = SeatsQuery.new(organization, { state: ['open', 'filled'] })
        results = query.call
        
        expect(results).to include(open_seat, filled_seat)
        expect(results).not_to include(draft_seat, archived_seat)
      end
    end

    context 'with has_direct_reports filter' do
      it 'filters to seats with direct reports when true' do
        query = SeatsQuery.new(organization, { has_direct_reports: 'true' })
        results = query.call
        
        expect(results).to include(parent_seat)
        expect(results).not_to include(child_seat, child_seat2, draft_seat, open_seat)
      end

      it 'filters to seats without direct reports when false' do
        query = SeatsQuery.new(organization, { has_direct_reports: 'false' })
        results = query.call
        
        expect(results).to include(draft_seat, open_seat, filled_seat, archived_seat, child_seat, child_seat2)
        expect(results).not_to include(parent_seat)
      end
    end

    context 'with sorting' do
      it 'sorts by seat_needed_by (default)' do
        query = SeatsQuery.new(organization, {})
        results = query.call.to_a
        
        expect(results.first).to eq(draft_seat)
        expect(results.last).to eq(child_seat2)
      end

      it 'sorts by title' do
        query = SeatsQuery.new(organization, { sort: 'title' })
        results = query.call.to_a
        
        # Should be grouped by title, then by seat_needed_by
        title_seats = results.select { |s| s.title == title }
        title2_seats = results.select { |s| s.title == title2 }
        
        expect(title_seats.map(&:id)).to eq([draft_seat, open_seat, parent_seat, child_seat].map(&:id))
        expect(title2_seats.map(&:id)).to eq([filled_seat, archived_seat, child_seat2].map(&:id))
      end

      it 'sorts by state' do
        query = SeatsQuery.new(organization, { sort: 'state' })
        results = query.call.to_a
        
        # Should be sorted by state (alphabetically), then seat_needed_by
        states = results.map(&:state)
        # States are: archived, draft, draft, draft, draft, filled, open
        # But we also have parent_seat (draft), child_seat (draft), child_seat2 (draft)
        # So we have: archived, draft (x4), filled, open
        expect(states.first).to eq('archived')
        expect(states.last).to eq('open')
        # Check that states are generally in order
        state_order = ['archived', 'draft', 'filled', 'open']
        states.each_with_index do |state, idx|
          next if idx == 0
          prev_state = states[idx - 1]
          expect(state_order.index(state)).to be >= state_order.index(prev_state)
        end
      end
    end
  end

  describe '#current_filters' do
    it 'returns empty hash when no filters' do
      query = SeatsQuery.new(organization, {})
      expect(query.current_filters).to eq({})
    end

    it 'returns state filter' do
      query = SeatsQuery.new(organization, { state: ['open', 'filled'] })
      expect(query.current_filters[:state]).to eq(['open', 'filled'])
    end

    it 'returns has_direct_reports filter' do
      query = SeatsQuery.new(organization, { has_direct_reports: 'true' })
      expect(query.current_filters[:has_direct_reports]).to eq('true')
    end
  end

  describe '#current_sort' do
    it 'returns default sort' do
      query = SeatsQuery.new(organization, {})
      expect(query.current_sort).to eq('seat_needed_by')
    end

    it 'returns specified sort' do
      query = SeatsQuery.new(organization, { sort: 'title' })
      expect(query.current_sort).to eq('title')
    end
  end

  describe '#current_view' do
    it 'returns default view' do
      query = SeatsQuery.new(organization, {})
      expect(query.current_view).to eq('table')
    end

    it 'returns specified view' do
      query = SeatsQuery.new(organization, { view: 'seat_hierarchy' })
      expect(query.current_view).to eq('seat_hierarchy')
    end
  end

  describe '#has_active_filters?' do
    it 'returns false when no filters' do
      query = SeatsQuery.new(organization, {})
      expect(query.has_active_filters?).to be false
    end

    it 'returns true when filters are present' do
      query = SeatsQuery.new(organization, { state: ['open'] })
      expect(query.has_active_filters?).to be true
    end
  end
end

