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
    it 'renders the comparison page without a beta badge' do
      get organization_position_comparison_path(
        organization,
        left_position_id: position_a.id,
        right_position_id: position_b.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Position Comparison')
      expect(response.body).to include('page-context-nav__breadcrumb')
      expect(response.body).to include(organization_positions_path(organization))
      expect(response.body).not_to include('badge text-bg-warning')
      expect(response.body).to include('Position + Title Description')
      expect(response.body).to include('Assignments')
      expect(response.body).to include('Eligibility Requirements')
      expect(response.body).to include('Seats By Title')
    end

    it 'groups position dropdowns by department with departments sorted' do
      sales = create(:department, company: organization, name: 'Sales')
      engineering = create(:department, company: organization, name: 'Engineering')
      major = title.position_major_level
      sales_title = create(:title, company: organization, department: sales, external_title: 'Account Executive',
        position_major_level: major)
      eng_title = create(:title, company: organization, department: engineering, external_title: 'Backend Engineer',
        position_major_level: major)
      sales_level = create(:position_level, position_major_level: major, level: '4.1')
      eng_level = create(:position_level, position_major_level: major, level: '4.2')
      sales_position = create(:position, title: sales_title, position_level: sales_level)
      eng_position = create(:position, title: eng_title, position_level: eng_level)

      get organization_position_comparison_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('optgroup')
      expect(response.body).to include('label="Engineering"')
      expect(response.body).to include('label="Sales"')
      expect(response.body).to include(organization.display_name)
      engineering_idx = response.body.index('label="Engineering"')
      sales_idx = response.body.index('label="Sales"')
      expect(engineering_idx).to be < sales_idx
      expect(response.body).to include(sales_position.display_name)
      expect(response.body).to include(eng_position.display_name)
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
      expect(response.body).to include('Combined position + title description')
      expect(response.body).to include('Compare the combined description')
      expect(response.body).to include(organization_position_path(organization, position_a))
      expect(response.body).to include(organization_position_path(organization, position_b))
      expect(response.body).to include('Title Summary A')
      expect(response.body).to include('Position Summary B')
      expect(response.body).to include('Open:')
      expect(response.body).to include('Filled:')
      expect(response.body).to include(open_seat.display_name)
      expect(response.body).to include(filled_seat.display_name)
    end
  end
end
