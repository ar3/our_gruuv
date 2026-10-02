# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SeatsHelper, type: :helper do
  let(:organization) { create(:organization, :company) }
  let(:department) { create(:department, company: organization, name: 'Product') }
  let(:pml) { create(:position_major_level) }
  let(:dept_title) { create(:title, company: organization, department: department, position_major_level: pml, external_title: 'Product Manager') }
  let(:company_title) { create(:title, company: organization, department: nil, position_major_level: pml, external_title: 'Company Strategist') }

  describe '#seats_grouped_options_for_select' do
    it 'groups by department, labels status first, and includes filler casual name when filled' do
      open_seat = create(:seat, :open, title: dept_title, seat_needed_by: Date.new(2024, 1, 1))
      draft_seat = create(:seat, :draft, title: company_title, seat_needed_by: Date.new(2024, 2, 1))
      filled_seat = create(:seat, :filled, title: dept_title, seat_needed_by: Date.new(2024, 3, 1))
      person = create(:person, first_name: 'Alex', preferred_name: 'Alex')
      teammate = create(:teammate, :assigned_employee, person: person, organization: organization)
      create(:employment_tenure, :with_seat, company: organization, company_teammate: teammate, seat: filled_seat, ended_at: nil)
      seats = [open_seat, draft_seat]

      html = helper.seats_grouped_options_for_select(
        organization,
        seats: seats,
        selected_seat_id: filled_seat.id
      )

      expect(html).to include('optgroup label="Product"')
      expect(html).to include('optgroup label="Company-wide"')
      expect(html).to include("Open · #{open_seat.display_name}")
      expect(html).to include("Draft · #{draft_seat.display_name}")
      expect(html).to include("Filled · #{filled_seat.display_name} (Alex)")
    end
  end

  describe 'state quick filter' do
    describe '#seat_state_quick_filter_selection' do
      it 'maps empty and single-state presets' do
        expect(helper.seat_state_quick_filter_selection({})).to eq(:all)
        expect(helper.seat_state_quick_filter_selection(state: %w[filled])).to eq(:filled)
        expect(helper.seat_state_quick_filter_selection(state: %w[open])).to eq(:unfilled)
        expect(helper.seat_state_quick_filter_selection(state: %w[filled open])).to eq(:all_open)
        expect(helper.seat_state_quick_filter_selection(state: %w[draft])).to eq(:draft)
      end

      it 'marks other multi-state filters as custom' do
        expect(helper.seat_state_quick_filter_selection(state: %w[open draft])).to eq(:custom)
        expect(helper.seat_state_quick_filter_selection(state: %w[archived])).to eq(:custom)
      end
    end

    describe '#seat_state_quick_filter_path' do
      before do
        allow(helper).to receive(:params).and_return(
          ActionController::Parameters.new(view: 'table', sort: 'title', state: %w[draft])
        )
      end

      it 'sets state for a preset and preserves other params' do
        path = helper.seat_state_quick_filter_path(organization, :filled)
        expect(path).to include('state%5B%5D=filled')
        expect(path).to include('view=table')
        expect(path).to include('sort=title')
      end

      it 'maps unfilled to open state' do
        path = helper.seat_state_quick_filter_path(organization, :unfilled)
        expect(path).to include('state%5B%5D=open')
        expect(path).not_to include('filled')
        expect(path).not_to include('draft')
      end

      it 'maps all_open to open and filled' do
        path = helper.seat_state_quick_filter_path(organization, :all_open)
        expect(path).to include('state%5B%5D=open')
        expect(path).to include('state%5B%5D=filled')
        expect(path).not_to include('draft')
        expect(path).not_to include('archived')
      end

      it 'clears state for all' do
        path = helper.seat_state_quick_filter_path(organization, :all)
        expect(path).not_to include('state')
        expect(path).to include('view=table')
      end
    end
  end
end
