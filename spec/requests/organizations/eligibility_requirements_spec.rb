require 'rails_helper'

RSpec.describe 'Organizations::EligibilityRequirements', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:company_teammate, person: person, organization: organization) }
  let(:title) { create(:title, company: organization) }
  let(:position_level) { create(:position_level, position_major_level: title.position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }

  before do
    teammate
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/eligibility_requirements' do
    it 'renders the eligibility requirements index' do
      get organization_eligibility_requirements_path(organization)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Eligibility Requirements')
    end
  end

  describe 'GET /organizations/:organization_id/eligibility_requirements/:id' do
    before do
      position.update!(
        eligibility_requirements_explicit: {
          "mileage_requirements" => {
            "minimum_mileage_points" => 0
          }
        }
      )
    end

    it 'renders eligibility requirements for the selected teammate and position' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      report = controller.instance_variable_get(:@eligibility_report)
      expect(report).to be_present
      expect(report[:position]).to eq(position)
      expect(report[:teammate]).to eq(teammate)
    end

    it 'renders conversation-style intro with teammate and position links' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('In order for')
      expect(response.body).to include('to be eligible for consideration of')
      expect(response.body).to include(organization_position_path(organization, position))
      expect(response.body).to include(internal_organization_company_teammate_path(organization, teammate))
    end

    it 'renders section (1) managerial hierarchy and section (2) business need cards' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('(1) Non-OurGruuv-related eligibility requirements')
      expect(response.body).to include('Expand for details')
      expect(response.body).to include('OurGruuv tries to make eligibility as clear as possible')
      expect(response.body).to include('(2) There has to be a business need')
      expect(response.body).to include('business need')
    end

    it 'shows business need eligible when teammate is in a seat for the position title' do
      title_for_position = position.title
      seat = create(:seat, title: title_for_position, seat_needed_by: 1.month.from_now, state: :filled)
      EmploymentTenure.create!(
        company_teammate: teammate,
        company: organization,
        position: position,
        seat: seat,
        started_at: 1.month.ago,
        ended_at: nil
      )

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Eligible')
      expect(controller.instance_variable_get(:@business_need_eligible)).to eq(true)
    end

    it 'shows business need not eligible when no open seat and teammate not in seat for position title' do
      # No seats for this position's title, and teammate has no tenure in that seat
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Not eligible / no business need defined')
      expect(controller.instance_variable_get(:@business_need_eligible)).to eq(false)
    end

    it 'renders aspirational values section with a table' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Aspirational Values')
      expect(response.body).to include('<table')
      expect(response.body).to include('Requirement')
      expect(response.body).to include('Position Requirement')
      expect(response.body).to include('Teammate Status')
    end

    it 'renders sections (3), (4) as cards with collapsed body and (5) only when unique assignments exist' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('(3) You must exemplify our Aspirational Values')
      expect(response.body).to include('(4) You must pass criteria for Required Assignments')
      expect(response.body).to include('section3Body')
      expect(response.body).to include('section4Body')
    end

    it 'hides section (5) when there are no unique-to-you assignments' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('(5) You must pass criteria for Unique-to-You Assignments')
    end

    it 'renders 12 status blocks per aspirational value row when aspirations exist' do
      create(:aspiration, company: organization, name: 'Integrity', sort_order: 0)

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Integrity')
      # Each block has inline style "width: 12px; height: 12px; min-width: 12px;"
      block_count = response.body.scan('12px; height: 12px').size
      expect(block_count).to eq(12), "Expected 12 status blocks for the one aspiration row, got #{block_count}"
    end

    it 'shows green block for month with finalized check-in rated exceeding' do
      aspiration = create(:aspiration, company: organization, name: 'Excellence', sort_order: 0)
      target_month = 3.months.ago.beginning_of_month.to_date
      create(:aspiration_check_in, :finalized,
        teammate: teammate,
        aspiration: aspiration,
        check_in_started_on: target_month,
        official_rating: 'exceeding'
      )

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Excellence')
      # That month's block should be green (bg-success)
      expect(response.body).to include('bg-success')
    end

    it 'uses 3-level eligibility summary: Exceed (maybe), Meet (maybe), and Eligible or Working to Meet' do
      position.update!(
        eligibility_requirements_explicit: position.eligibility_requirements_explicit.merge(
          'company_aspirational_values_check_in_requirements' => {
            'minimum_months_at_or_above_rating_criteria' => 12,
            'minimum_percentage_of_aspirational_values_meeting' => 80,
            'minimum_percentage_of_aspirational_values_exceeding' => 20
          }
        )
      )
      create(:aspiration, company: organization, name: 'Integrity', sort_order: 0)

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Exceed (maybe)')
      expect(response.body).to include('Meet (maybe)')
      expect(response.body).to match(/Eligible|Working to meet requirements/)
    end

    it 'shows row status using new category labels (Exceeding, Meeting, Miss, Unknown, etc.)' do
      position.update!(
        eligibility_requirements_explicit: position.eligibility_requirements_explicit.merge(
          'company_aspirational_values_check_in_requirements' => {
            'minimum_months_at_or_above_rating_criteria' => 12,
            'minimum_percentage_of_aspirational_values_meeting' => 80,
            'minimum_percentage_of_aspirational_values_exceeding' => 20
          }
        )
      )
      create(:aspiration, company: organization, name: 'Integrity', sort_order: 0)

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      # Total row uses new category names
      expect(response.body).to include('Exceeding')
      expect(response.body).to include('Maybe Exceeding')
      expect(response.body).to include('Meeting')
      expect(response.body).to include('Maybe Meeting')
      expect(response.body).to include('Miss')
      expect(response.body).to include('Unknown')
    end

    it 'renders sections (6) Required Milestones and (7) Milestone Mileage as cards' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('(6) You must pass criteria for Required Milestones')
      expect(response.body).to include('(7) You must meet the required Milestone Mileage')
      expect(response.body).to include('section6Body')
      expect(response.body).to include('section7Body')
    end

    it 'renders section (8) position ratings when position check-in requirements are configured' do
      position.update!(
        eligibility_requirements_explicit: position.eligibility_requirements_explicit.merge(
          'position_check_in_requirements' => {
            'minimum_rating' => 2,
            'minimum_months_at_or_above_rating_criteria' => 6
          }
        )
      )

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('(8) You must meet the Required Overall position ratings')
      expect(response.body).to include('section8Body')
      expect(response.body).to include('Position check-ins (past 12 months)')
      expect(controller.instance_variable_get(:@position_check_in_eligibility_result)).to be_present
    end

    it 'does not render section (8) when position check-in requirements are not configured' do
      position.update!(
        eligibility_requirements_explicit: {
          'mileage_requirements' => { 'minimum_mileage_points' => 0 }
        }
      )

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).not_to include('(8) You must meet the Required Overall position ratings')
      expect(controller.instance_variable_get(:@position_check_in_eligibility_result)).to be_nil
    end
  end
end
