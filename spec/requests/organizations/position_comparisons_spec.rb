require 'rails_helper'

RSpec.describe 'Organizations::PositionComparisons', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:title_b) { create(:title, company: organization) }
  let(:position_level_a) { create(:position_level, position_major_level: title.position_major_level, level: '1.1') }
  let(:position_level_b) { create(:position_level, position_major_level: title_b.position_major_level, level: '1.1') }
  let(:position_a) { create(:position, title: title, position_level: position_level_a) }
  let(:position_b) { create(:position, title: title_b, position_level: position_level_b) }

  before do
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/position_comparison' do
    it 'renders the comparison page and beta header badge' do
      get organization_position_comparison_path(
        organization,
        left_position_id: position_a.id,
        right_position_id: position_b.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Position Comparison')
      expect(response.body).to include('Beta')
      expect(response.body).to include('Position + Title Description')
      expect(response.body).to include('Assignments')
      expect(response.body).to include('Eligibility Requirements')
      expect(response.body).to include('Seats By Title')
    end

    it 'shows a side-by-side assignment row with fallback when missing on one side' do
      assignment = create(:assignment, company: organization, title: 'Client Discovery', tagline: 'Discover client needs')
      create(:assignment_outcome, assignment: assignment, description: 'Capture top priorities')
      ability = create(:ability, company: organization, name: 'Communication')
      create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
      create(:position_assignment, position: position_a, assignment: assignment, assignment_type: 'required')

      get organization_position_comparison_path(
        organization,
        left_position_id: position_a.id,
        right_position_id: position_b.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Client Discovery')
      expect(response.body).to include('Discover client needs')
      expect(response.body).to include('Capture top priorities')
      expect(response.body).to include('Client Discovery is not required or suggested for the position')
      expect(response.body).to include(position_b.display_name)
      expect(response.body).to include('position-comparison-empty-state')
      expect(response.body).to include('collapse')
    end

    it 'shows combined description and seats for each selected position title' do
      position_a.title.update!(position_summary: "## Title Summary A")
      position_a.update!(position_summary: "### Position Summary A")
      position_b.title.update!(position_summary: "## Title Summary B")
      position_b.update!(position_summary: "### Position Summary B")

      open_seat = create(:seat, title: position_a.title, state: :open, seat_needed_by: 1.month.from_now)
      filled_seat = create(:seat, title: position_b.title, state: :filled, seat_needed_by: 2.months.from_now)
      occupant = create(:company_teammate, organization: organization)
      EmploymentTenure.create!(
        company_teammate: occupant,
        company: organization,
        position: position_b,
        seat: filled_seat,
        started_at: 1.month.ago,
        ended_at: nil
      )

      get organization_position_comparison_path(
        organization,
        left_position_id: position_a.id,
        right_position_id: position_b.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Combined position + title markdown')
      expect(response.body).to include('Title Summary A')
      expect(response.body).to include('Position Summary B')
      expect(response.body).to include('Open:')
      expect(response.body).to include('Filled:')
      expect(response.body).to include(open_seat.display_name)
      expect(response.body).to include(filled_seat.display_name)
    end
  end
end
