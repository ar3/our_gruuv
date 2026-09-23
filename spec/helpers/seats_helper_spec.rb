# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SeatsHelper, type: :helper do
  let(:organization) { create(:organization, :company) }
  let(:department) { create(:department, company: organization, name: 'Product') }
  let(:pml) { create(:position_major_level) }
  let(:dept_title) { create(:title, company: organization, department: department, position_major_level: pml, external_title: 'Product Manager') }
  let(:company_title) { create(:title, company: organization, department: nil, position_major_level: pml, external_title: 'Company Strategist') }

  describe '#seats_grouped_options_for_select' do
    it 'groups by department, labels status, and includes filled only when selected' do
      open_seat = create(:seat, :open, title: dept_title, seat_needed_by: Date.new(2024, 1, 1))
      draft_seat = create(:seat, :draft, title: company_title, seat_needed_by: Date.new(2024, 2, 1))
      filled_seat = create(:seat, :filled, title: dept_title, seat_needed_by: Date.new(2024, 3, 1))
      seats = [open_seat, draft_seat]

      html = helper.seats_grouped_options_for_select(
        organization,
        seats: seats,
        selected_seat_id: filled_seat.id
      )

      expect(html).to include('optgroup label="Product"')
      expect(html).to include("optgroup label=\"#{organization.display_name}\"")
      expect(html).to include("#{open_seat.display_name} (Open)")
      expect(html).to include("#{draft_seat.display_name} (Draft)")
      expect(html).to include("#{filled_seat.display_name} (Filled)")
    end
  end
end
