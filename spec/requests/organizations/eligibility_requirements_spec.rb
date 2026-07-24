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
      assign_position_eligibility_from_hash!(
        position,
        'mileage_requirements' => { 'threshold_type' => 'absolute', 'threshold_value' => 0 }
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

    it 'includes the selected teammate Growth Position Change crumb in breadcrumbs' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      casual = teammate.person.casual_name.presence || teammate.person.display_name
      expect(response).to have_http_status(:success)
      expect(response.body).to include(ERB::Util.html_escape("#{casual}'s Growth : Position Change"))
      expect(response.body).to include(
        my_growth_position_change_organization_company_teammate_path(organization, teammate)
      )
    end

    it 'includes page help for eligibility requirements' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('eligibilityRequirementsPageHelp')
      expect(response.body).to include('Goal of this page')
      expect(response.body).to include('What is MAAP?')
      expect(response.body).not_to include('Overall Eligibility:')
    end

    it 'renders managerial hierarchy and business need cards without section numbers' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Non-OurGruuv-related eligibility requirements')
      expect(response.body).not_to include('(1) Non-OurGruuv-related')
      expect(response.body).to include('Expand for details')
      expect(response.body).to include('OurGruuv tries to make eligibility as clear')
      expect(response.body).to include('There has to be a business need')
      expect(response.body).not_to include('(2) There has to be a business need')
      expect(response.body).to include('business need')
      expect(response.body).not_to include('id="irrelevantEligibilityCriteria"')
    end

    it 'hides business need and lists it under Irrelevant criteria when teammate already holds this title' do
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
      expect(response.body).not_to include('No Current Business Need')
      expect(response.body).not_to include('section2Body')
      expect(response.body).to include('id="irrelevantEligibilityCriteria"')
      expect(response.body).to include('already holds a seat with this title')
      expect(response.body).to include(title_for_position.display_name)
      expect(controller.instance_variable_get(:@show_business_need_criterion)).to eq(false)
      expect(controller.instance_variable_get(:@business_need_eligible)).to eq(true)
    end

    it 'shows business need when teammate holds a different title' do
      other_title = create(:title, company: organization)
      other_seat = create(:seat, title: other_title, seat_needed_by: 1.month.from_now, state: :filled)
      other_position_level = create(:position_level, position_major_level: other_title.position_major_level)
      other_position = create(:position, title: other_title, position_level: other_position_level)
      EmploymentTenure.create!(
        company_teammate: teammate,
        company: organization,
        position: other_position,
        seat: other_seat,
        started_at: 1.month.ago,
        ended_at: nil
      )

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('There has to be a business need')
      expect(response.body).to include('section2Body')
      expect(response.body).to include('No Current Business Need')
      expect(response.body).not_to include('id="irrelevantEligibilityCriteria"')
      expect(controller.instance_variable_get(:@show_business_need_criterion)).to eq(true)
      expect(controller.instance_variable_get(:@business_need_eligible)).to eq(false)
    end

    it 'shows business need not eligible when no open seat and teammate not in seat for position title' do
      # No seats for this position's title, and teammate has no tenure in that seat
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('No Current Business Need')
      expect(controller.instance_variable_get(:@business_need_eligible)).to eq(false)
      expect(controller.instance_variable_get(:@show_business_need_criterion)).to eq(true)
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

    it 'renders aspirational values, required assignments, and unique-to-you as cards with collapsed body' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Criteria for exemplifying our Aspirational Values')
      expect(response.body).to include('Criteria for Required Assignments')
      expect(response.body).to include('Criteria for Unique-to-You Assignments')
      expect(response.body).not_to include('(3) Criteria for exemplifying')
      expect(response.body).to include('section3Body')
      expect(response.body).to include('section4Body')
      expect(response.body).to include('section5Body')
    end

    it 'always shows Unique-to-You Assignments; shows Not applicable when no minimum meeting expectation' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Criteria for Unique-to-You Assignments')
      # With no unique-to-you requirements configured (or 0% expectation) and no assignments, show Not applicable
      expect(response.body).to include('Not applicable')
      expect(response.body).to include('bg-info')
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
      # With default eligibility requirements, section (8) also has one row with 12 blocks, so we get at least 12 from aspirations
      block_count = response.body.scan('12px; height: 12px').size
      expect(block_count).to be >= 12, "Expected at least 12 status blocks (aspirational row + position row), got #{block_count}"
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

    it 'uses 3-level eligibility summary: Exceeding, On-Track to be Exceeding, Meeting, On-Track to be Meeting, and Eligible or Working to Meet' do
      h = position.reload.position_eligibility_requirement.to_eligibility_service_hash.merge(
        'company_aspirational_values_check_in_requirements' => {
          'minimum_months_at_or_above_rating_criteria' => 12,
          'minimum_percentage_of_aspirational_values_meeting' => 80,
          'minimum_percentage_of_aspirational_values_exceeding' => 20
        }
      )
      assign_position_eligibility_from_hash!(position, h)
      create(:aspiration, company: organization, name: 'Integrity', sort_order: 0)

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('On-Track to be Exceeding')
      expect(response.body).to include('On-Track to be Meeting')
      expect(response.body).to match(/Eligible|Working to meet requirements/)
    end

    it 'shows row status using new category labels (Exceeding, Meeting, Miss, Unknown, etc.)' do
      h = position.reload.position_eligibility_requirement.to_eligibility_service_hash.merge(
        'company_aspirational_values_check_in_requirements' => {
          'minimum_months_at_or_above_rating_criteria' => 12,
          'minimum_percentage_of_aspirational_values_meeting' => 80,
          'minimum_percentage_of_aspirational_values_exceeding' => 20
        }
      )
      assign_position_eligibility_from_hash!(position, h)
      create(:aspiration, company: organization, name: 'Integrity', sort_order: 0)

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      # Total row uses new category names
      expect(response.body).to include('Exceeding')
      expect(response.body).to include('On-Track to be Exceeding')
      expect(response.body).to include('Meeting')
      expect(response.body).to include('On-Track to be Meeting')
      expect(response.body).to include('Miss')
      expect(response.body).to include('Unknown')
    end

    it 'renders Required Milestones and Milestone Mileage as cards' do
      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Criteria for Required Milestones')
      expect(response.body).to include('Required Milestone Mileage')
      expect(response.body).not_to include('(6) Criteria for Required Milestones')
      expect(response.body).not_to include('(7) Required Milestone Mileage')
      expect(response.body).to include('section6Body')
      expect(response.body).to include('section7Body')
    end

    it 'groups required milestone mileage by ability (cumulative points through highest required level), sorted by ability name' do
      ability_leadership = create(:ability, company: organization, name: 'Leadership')
      ability_communication = create(:ability, company: organization, name: 'Communication')
      create(:position_ability, position: position, ability: ability_leadership, milestone_level: 2)
      create(:position_ability, position: position, ability: ability_communication, milestone_level: 1)
      required_assignment = create(:assignment, company: organization, title: 'Required Role')
      create(:position_assignment, position: position, assignment: required_assignment, assignment_type: 'required')
      create(:assignment_ability, assignment: required_assignment, ability: ability_leadership, milestone_level: 2)

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      required = controller.instance_variable_get(:@mileage_required_addends)
      addends = required[:addends]
      # One row per ability: Communication M1 => 1 pt; Leadership M2 => 1+2 = 3 pts
      expect(addends.map { |a| [a[:ability_name], a[:levels], a[:points]] }).to eq([
        ['Communication', [1], 1],
        ['Leadership', [1, 2], 3]
      ])
      expect(addends).to eq(addends.sort_by { |a| a[:ability_name] })
    end

    it 'renders position ratings when position check-in requirements are configured' do
      h = position.reload.position_eligibility_requirement.to_eligibility_service_hash.merge(
        'position_check_in_requirements' => {
          'minimum_rating' => 2,
          'minimum_months_at_or_above_rating_criteria' => 6
        }
      )
      assign_position_eligibility_from_hash!(position, h)

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Required Overall position ratings')
      expect(response.body).not_to include('(8) Required Overall position ratings')
      expect(response.body).to include('section8Body')
      expect(response.body).to include('Position check-ins (past 12 months)')
      expect(controller.instance_variable_get(:@position_check_in_eligibility_result)).to be_present
    end

    it 'renders position ratings with default position check-in requirements when none are set on the position' do
      position.update!(position_eligibility_requirement_id: nil)

      get organization_eligibility_requirement_path(
        organization,
        position,
        teammate_id: teammate.id
      )

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Required Overall position ratings')
      expect(controller.instance_variable_get(:@position_check_in_eligibility_result)).to be_present
    end
  end
end
