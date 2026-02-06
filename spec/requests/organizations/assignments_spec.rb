require 'rails_helper'

RSpec.describe 'Organizations::Assignments', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:manager) { create(:person) }
  let(:assignment) { create(:assignment, company: organization) }

  let(:person_teammate) { create(:teammate, person: person, organization: organization) }
  let(:admin_teammate) { create(:teammate, person: admin, organization: organization) }
  let(:manager_teammate) { create(:teammate, person: manager, organization: organization, can_manage_employment: true, can_manage_maap: true) }

  before do
    # Temporarily disable PaperTrail for request tests to avoid controller_info issues
    PaperTrail.enabled = false
  end

  after do
    # Re-enable PaperTrail after tests
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/assignments' do
    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'allows access to index' do
        get organization_assignments_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Assignments')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access to index' do
        get organization_assignments_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Assignments')
      end
    end
  end

  describe 'GET /organizations/:organization_id/assignments/:id' do
    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'allows access to show' do
        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(assignment.title)
      end

      it 'renders view switcher' do
        get organization_assignment_path(organization, assignment)
        expect(response.body).to include('Organization View')
        expect(response.body).to include('Public View')
      end

      it 'shows disabled edit and delete options for non-admin users' do
        get organization_assignment_path(organization, assignment)
        expect(response.body).to include('Edit Assignment')
        expect(response.body).to include('Delete Assignment')
      end

      it 'shows current holders section when there are active tenures' do
        teammate1 = create(:teammate, person: create(:person), organization: organization)
        teammate2 = create(:teammate, person: create(:person), organization: organization)
        create(:assignment_tenure, teammate: teammate1, assignment: assignment, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: 50)
        create(:assignment_tenure, teammate: teammate2, assignment: assignment, started_at: 2.months.ago, ended_at: nil, anticipated_energy_percentage: 75)

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Current Holders of This Assignment')
        expect(response.body).to include(teammate1.person.display_name)
        expect(response.body).to include(teammate2.person.display_name)
        expect(response.body).to include('(50%)')
        expect(response.body).to include('(75%)')
      end

      it 'shows current holders without percentage when anticipated_energy_percentage is nil' do
        teammate1 = create(:teammate, person: create(:person), organization: organization)
        create(:assignment_tenure, teammate: teammate1, assignment: assignment, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: nil)

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Current Holders of This Assignment')
        expect(response.body).to include(teammate1.person.display_name)
        expect(response.body).not_to match(/\(nil%\)/)
      end

      it 'sorts current holders by last name, preferred name, first name' do
        # Create teammates with different names to test sorting
        # Test that sorting works by last name first, then preferred name, then first name
        person1 = create(:person, last_name: 'Zebra', first_name: 'Alice')
        person2 = create(:person, last_name: 'Apple', first_name: 'Robert')
        person3 = create(:person, last_name: 'Apple', first_name: 'Charles')
        person4 = create(:person, last_name: 'Apple', first_name: 'David')
        
        # Set preferred names directly in database to avoid validation issues
        Person.where(id: person2.id).update_all(preferred_name: 'Bob')
        Person.where(id: person3.id).update_all(preferred_name: 'Charlie')
        Person.where(id: person1.id).update_all(preferred_name: nil)
        Person.where(id: person4.id).update_all(preferred_name: nil)
        
        # Reload to get updated values
        person1.reload
        person2.reload
        person3.reload
        person4.reload
        
        teammate1 = create(:teammate, person: person1, organization: organization)
        teammate2 = create(:teammate, person: person2, organization: organization)
        teammate3 = create(:teammate, person: person3, organization: organization)
        teammate4 = create(:teammate, person: person4, organization: organization)
        
        create(:assignment_tenure, teammate: teammate1, assignment: assignment, started_at: 1.month.ago, ended_at: nil)
        create(:assignment_tenure, teammate: teammate2, assignment: assignment, started_at: 1.month.ago, ended_at: nil)
        create(:assignment_tenure, teammate: teammate3, assignment: assignment, started_at: 1.month.ago, ended_at: nil)
        create(:assignment_tenure, teammate: teammate4, assignment: assignment, started_at: 1.month.ago, ended_at: nil)

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        
        # Get the actual order from the controller
        holders = assigns(:current_holders)
        expect(holders.length).to eq(4)
        
        # Get sorted keys for verification
        sorted_keys = holders.map do |h|
          p = h.person
          [p.last_name.to_s.downcase, p.preferred_name.to_s.downcase, p.first_name.to_s.downcase]
        end
        
        # Verify the list is sorted correctly
        expect(sorted_keys).to eq(sorted_keys.sort)
        
        # Verify specific order: Apple/Bob, Apple/Charlie, Apple/David, Zebra/Alice
        # Apple should come before Zebra
        apple_indices = holders.each_with_index.select { |h, _| h.person.last_name == 'Apple' }.map(&:last)
        zebra_index = holders.each_with_index.find { |h, _| h.person.last_name == 'Zebra' }&.last
        
        expect(apple_indices.max).to be < zebra_index
      end

      it 'shows no current holders message when there are no active tenures' do
        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Current Holders of This Assignment')
        expect(response.body).to include('No current holders')
      end

      it 'shows analytics section with all metrics' do
        teammate1 = create(:teammate, person: create(:person), organization: organization)
        teammate2 = create(:teammate, person: create(:person), organization: organization)
        teammate3 = create(:teammate, person: create(:person), organization: organization)
        
        # Create some tenures
        create(:assignment_tenure, teammate: teammate1, assignment: assignment, started_at: 3.months.ago, ended_at: 1.month.ago)
        create(:assignment_tenure, teammate: teammate2, assignment: assignment, started_at: 2.months.ago, ended_at: nil, anticipated_energy_percentage: 50)
        create(:assignment_tenure, teammate: teammate3, assignment: assignment, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: 75)
        
        # Create some finalized check-ins
        manager_teammate_for_check_in = create(:company_teammate, person: create(:person), organization: organization)
        finalized_teammate = create(:company_teammate, person: create(:person), organization: organization)
        check_in1 = create(:assignment_check_in, teammate: teammate1, assignment: assignment, check_in_started_on: 2.months.ago, official_check_in_completed_at: 2.months.ago, official_rating: 'meeting', employee_personal_alignment: 'like', manager_completed_by_teammate: manager_teammate_for_check_in, finalized_by_teammate: finalized_teammate)
        check_in2 = create(:assignment_check_in, teammate: teammate2, assignment: assignment, check_in_started_on: 1.month.ago, official_check_in_completed_at: 1.month.ago, official_rating: 'exceeding', employee_personal_alignment: 'love', manager_completed_by_teammate: manager_teammate_for_check_in, finalized_by_teammate: finalized_teammate)

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Analytics')
        expect(response.body).to include('Teammates with Tenure')
        expect(response.body).to include('Total Finalized Check-ins')
        expect(response.body).to include('Active Assignment Tenures')
        expect(response.body).to include('Average Anticipated Energy')
        expect(response.body).to include('Most Popular Official Rating')
        expect(response.body).to include('Most Popular Personal Alignment')
      end

      it 'shows message for popular ratings when less than 5 teammates have finalized check-ins' do
        teammate1 = create(:teammate, person: create(:person), organization: organization)
        teammate2 = create(:teammate, person: create(:person), organization: organization)
        
        manager_teammate_for_check_in = create(:company_teammate, person: create(:person), organization: organization)
        finalized_teammate = create(:company_teammate, person: create(:person), organization: organization)
        check_in1 = create(:assignment_check_in, teammate: teammate1, assignment: assignment, check_in_started_on: 1.month.ago, official_check_in_completed_at: 1.month.ago, official_rating: 'meeting', manager_completed_by_teammate: manager_teammate_for_check_in, finalized_by_teammate: finalized_teammate)
        check_in2 = create(:assignment_check_in, teammate: teammate2, assignment: assignment, check_in_started_on: 2.months.ago, official_check_in_completed_at: 2.months.ago, official_rating: 'exceeding', manager_completed_by_teammate: manager_teammate_for_check_in, finalized_by_teammate: finalized_teammate)

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('These analytics will be available once 5 or more teammates have had a finalized check-in.')
      end

      it 'shows most popular rating when 6 or more teammates have finalized check-ins' do
        teammates = 6.times.map { create(:teammate, person: create(:person), organization: organization) }
        
        manager_teammate_for_check_in = create(:company_teammate, person: create(:person), organization: organization)
        finalized_teammate = create(:company_teammate, person: create(:person), organization: organization)
        # Create 4 check-ins with 'meeting' rating and 2 with 'exceeding'
        teammates[0..3].each do |teammate|
          create(:assignment_check_in, teammate: teammate, assignment: assignment, check_in_started_on: 1.month.ago, official_check_in_completed_at: 1.month.ago, official_rating: 'meeting', manager_completed_by_teammate: manager_teammate_for_check_in, finalized_by_teammate: finalized_teammate)
        end
        teammates[4..5].each do |teammate|
          create(:assignment_check_in, teammate: teammate, assignment: assignment, check_in_started_on: 1.month.ago, official_check_in_completed_at: 1.month.ago, official_rating: 'exceeding', manager_completed_by_teammate: manager_teammate_for_check_in, finalized_by_teammate: finalized_teammate)
        end

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Meeting')
        expect(response.body).not_to include('These analytics will be available once 5 or more teammates have had a finalized check-in.')
      end

      it 'shows most popular personal alignment when 6 or more teammates have finalized check-ins' do
        teammates = 6.times.map { create(:teammate, person: create(:person), organization: organization) }
        
        manager_teammate_for_check_in = create(:company_teammate, person: create(:person), organization: organization)
        finalized_teammate = create(:company_teammate, person: create(:person), organization: organization)
        # Create 4 check-ins with 'love' alignment and 2 with 'like'
        teammates[0..3].each do |teammate|
          create(:assignment_check_in, teammate: teammate, assignment: assignment, check_in_started_on: 1.month.ago, official_check_in_completed_at: 1.month.ago, employee_personal_alignment: 'love', manager_completed_by_teammate: manager_teammate_for_check_in, finalized_by_teammate: finalized_teammate)
        end
        teammates[4..5].each do |teammate|
          create(:assignment_check_in, teammate: teammate, assignment: assignment, check_in_started_on: 1.month.ago, official_check_in_completed_at: 1.month.ago, employee_personal_alignment: 'like', manager_completed_by_teammate: manager_teammate_for_check_in, finalized_by_teammate: finalized_teammate)
        end

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Love')
        expect(response.body).not_to include('These analytics will be available once 5 or more teammates have had a finalized check-in.')
      end

      it 'calculates average anticipated energy correctly' do
        teammate1 = create(:teammate, person: create(:person), organization: organization)
        teammate2 = create(:teammate, person: create(:person), organization: organization)
        teammate3 = create(:teammate, person: create(:person), organization: organization)
        
        create(:assignment_tenure, teammate: teammate1, assignment: assignment, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: 50)
        create(:assignment_tenure, teammate: teammate2, assignment: assignment, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: 75)
        create(:assignment_tenure, teammate: teammate3, assignment: assignment, started_at: 1.month.ago, ended_at: nil, anticipated_energy_percentage: 25)

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        # Average should be (50 + 75 + 25) / 3 = 50.0
        expect(response.body).to include('50.0%')
      end

      it 'shows positions section when there are position assignments' do
        position_major_level = create(:position_major_level)
        title = create(:title, company: organization, position_major_level: position_major_level)
        position_level = create(:position_level, position_major_level: position_major_level)
        position = create(:position, title: title, position_level: position_level)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required', min_estimated_energy: 20, max_estimated_energy: 40)

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Positions that Require or Suggest This Assignment')
        expect(response.body).to include(position.display_name)
        expect(response.body).to include('(20%-40%)')
      end

      it 'shows required positions with energy percentage suffix' do
        position_major_level = create(:position_major_level)
        title = create(:title, company: organization, position_major_level: position_major_level)
        position_level1 = create(:position_level, position_major_level: position_major_level, level: '1.0')
        position_level2 = create(:position_level, position_major_level: position_major_level, level: '2.0')
        position1 = create(:position, title: title, position_level: position_level1)
        position2 = create(:position, title: title, position_level: position_level2)
        
        create(:position_assignment, position: position1, assignment: assignment, assignment_type: 'required', min_estimated_energy: 10, max_estimated_energy: 30)
        create(:position_assignment, position: position2, assignment: assignment, assignment_type: 'required', min_estimated_energy: 25)

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Required Positions (2)')
        expect(response.body).to include(position1.display_name)
        expect(response.body).to include('(10%-30%)')
        expect(response.body).to include(position2.display_name)
        expect(response.body).to include('(25%+)')
      end

      it 'shows suggested positions with energy percentage suffix' do
        position_major_level = create(:position_major_level)
        title = create(:title, company: organization, position_major_level: position_major_level)
        position_level = create(:position_level, position_major_level: position_major_level)
        position = create(:position, title: title, position_level: position_level)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'suggested', max_estimated_energy: 50)

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Suggested Positions (1)')
        expect(response.body).to include(position.display_name)
        expect(response.body).to include('(up to 50%)')
      end

      it 'shows both required and suggested positions when both exist' do
        position_major_level = create(:position_major_level)
        title = create(:title, company: organization, position_major_level: position_major_level)
        position_level1 = create(:position_level, position_major_level: position_major_level, level: '1.0')
        position_level2 = create(:position_level, position_major_level: position_major_level, level: '2.0')
        required_position = create(:position, title: title, position_level: position_level1)
        suggested_position = create(:position, title: title, position_level: position_level2)
        
        create(:position_assignment, position: required_position, assignment: assignment, assignment_type: 'required', min_estimated_energy: 20, max_estimated_energy: 40)
        create(:position_assignment, position: suggested_position, assignment: assignment, assignment_type: 'suggested', min_estimated_energy: 10, max_estimated_energy: 20)

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Required Positions (1)')
        expect(response.body).to include('Suggested Positions (1)')
        expect(response.body).to include(required_position.display_name)
        expect(response.body).to include(suggested_position.display_name)
      end

      it 'does not show positions section when there are no position assignments' do
        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).not_to include('Positions that Require or Suggest This Assignment')
      end

      context 'when assignment has outcomes' do
        let!(:outcome) do
          create(:assignment_outcome, assignment: assignment, description: 'Ship features on time', outcome_type: 'quantitative')
        end

        it 'displays outcome description so it can be copied (outcome text is not a link)' do
          get organization_assignment_path(organization, assignment)
          expect(response).to have_http_status(:success)
          expect(response.body).to include('Ship features on time')
        end
      end

      it 'links positions to their show pages' do
        position_major_level = create(:position_major_level)
        title = create(:title, company: organization, position_major_level: position_major_level)
        position_level = create(:position_level, position_major_level: position_major_level)
        position = create(:position, title: title, position_level: position_level)
        create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')

        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        # Position's company is the title's organization
        expect(response.body).to include(organization_position_path(position.company, position))
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access to show' do
        get organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(assignment.title)
      end

      it 'renders view switcher with all options enabled' do
        get organization_assignment_path(organization, assignment)
        expect(response.body).to include('Organization View')
        expect(response.body).to include('Public View')
        expect(response.body).to include('Manage Ability Milestones')
        expect(response.body).to include('Edit Assignment')
        expect(response.body).to include('Delete Assignment')
      end

      context 'when assignment has outcomes' do
        let!(:outcome_no_config) do
          create(:assignment_outcome, assignment: assignment, description: 'Outcome with no config', outcome_type: 'quantitative',
            progress_report_url: nil, management_relationship_filter: nil, team_relationship_filter: nil, consumer_assignment_filter: nil)
        end
        let!(:outcome_with_config) do
          create(:assignment_outcome, assignment: assignment, description: 'Outcome with config', outcome_type: 'sentiment',
            progress_report_url: 'https://example.com/report')
        end

        it 'shows "Add add\'l config" badge (grey) when outcome has no additional config' do
          get organization_assignment_path(organization, assignment)
          expect(response).to have_http_status(:success)
          expect(response.body).to include("Add add&#39;l config")
          expect(response.body).to include('bg-secondary')
        end

        it 'shows "Modify/View add\'l config" badge (info) when outcome has additional config' do
          get organization_assignment_path(organization, assignment)
          expect(response).to have_http_status(:success)
          expect(response.body).to include("Modify/View add&#39;l config")
          expect(response.body).to include('bg-info')
        end

        it 'links the additional configuration badge to the outcome edit page' do
          get organization_assignment_path(organization, assignment)
          expect(response).to have_http_status(:success)
          edit_path = edit_organization_assignment_assignment_outcome_path(organization, assignment, outcome_no_config)
          expect(response.body).to include(edit_path)
        end

        it 'displays outcome description as plain text (not wrapped in a link)' do
          get organization_assignment_path(organization, assignment)
          expect(response.body).to include('Outcome with no config')
          expect(response.body).to include('Outcome with config')
          # Each outcome edit path should appear only once (for the badge), not for the description
          expect(response.body.scan(edit_organization_assignment_assignment_outcome_path(organization, assignment, outcome_no_config)).size).to eq(1)
          expect(response.body.scan(edit_organization_assignment_assignment_outcome_path(organization, assignment, outcome_with_config)).size).to eq(1)
        end
      end
    end

    context 'when user is manager with employment permissions' do
      before do
        manager_teammate
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'shows enabled edit option but disabled delete option' do
        get organization_assignment_path(organization, assignment)
        expect(response.body).to include('Edit Assignment')
        expect(response.body).to include('Manage Ability Milestones')
      end
    end
  end

  describe 'GET /organizations/:organization_id/assignments/new' do
    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        get new_organization_assignment_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is manager with employment permissions' do
      before do
        manager_teammate
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows access' do
        get new_organization_assignment_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New Assignment')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access' do
        get new_organization_assignment_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New Assignment')
      end
    end
  end

  describe 'GET /organizations/:organization_id/assignments with department filters' do
    let!(:department1) { create(:department, company: organization) }
    let!(:department2) { create(:department, company: organization) }
    let!(:department3) { create(:department, company: organization) }
    let!(:assignment_dept1) { create(:assignment, company: organization, department: department1) }
    let!(:assignment_dept2) { create(:assignment, company: organization, department: department2) }
    let!(:assignment_no_dept) { create(:assignment, company: organization, department: nil) }
    let!(:other_assignment) { create(:assignment, company: organization, department: department3) }

    before do
      person_teammate
      sign_in_as_teammate_for_request(person, organization)
    end

    it 'returns assignments from selected departments' do
      get organization_assignments_path(organization, departments: "#{department1.id},#{department2.id}")
      
      expect(response).to have_http_status(:success)
      assignments = assigns(:assignments).to_a
      
      expect(assignments).to include(assignment_dept1, assignment_dept2)
      expect(assignments).not_to include(assignment_no_dept, other_assignment)
    end

    it 'returns assignments from company (nil department) when "none" is selected' do
      get organization_assignments_path(organization, departments: 'none')
      
      expect(response).to have_http_status(:success)
      assignments = assigns(:assignments).to_a
      
      expect(assignments).to include(assignment_no_dept)
      expect(assignments).not_to include(assignment_dept1, assignment_dept2)
    end

    it 'returns assignments from both company and departments when both are selected' do
      get organization_assignments_path(organization, departments: "none,#{department1.id}")
      
      expect(response).to have_http_status(:success)
      assignments = assigns(:assignments).to_a
      
      expect(assignments).to include(assignment_no_dept, assignment_dept1)
      expect(assignments).not_to include(assignment_dept2, other_assignment)
    end
  end

  describe 'POST /organizations/:organization_id/assignments' do
    let(:valid_params) do
      {
        assignment: {
          title: 'Test Assignment',
          tagline: 'Test tagline',
          version_type: 'ready'
        }
      }
    end

    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        assignment # Ensure assignment exists
        initial_count = Assignment.count
        post organization_assignments_path(organization), params: valid_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(Assignment.count).to eq(initial_count) # No new assignment created
      end
    end

    context 'when user is manager with employment permissions' do
      before do
        manager_teammate
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows access and creates assignment' do
        expect {
          post organization_assignments_path(organization), params: valid_params
        }.to change(Assignment, :count).by(1)
        
        expect(response).to have_http_status(:redirect)
        expect(Assignment.last.title).to eq('Test Assignment')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access and creates assignment' do
        expect {
          post organization_assignments_path(organization), params: valid_params
        }.to change(Assignment, :count).by(1)
        
        expect(response).to have_http_status(:redirect)
        expect(Assignment.last.title).to eq('Test Assignment')
      end
    end
  end

  describe 'GET /organizations/:organization_id/assignments/:id/edit' do
    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        get edit_organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is manager with employment permissions' do
      before do
        manager_teammate
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows access and renders edit form' do
        get edit_organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Edit Assignment')
        expect(response.body).to include(assignment.title)
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access and renders edit form without HAML errors' do
        get edit_organization_assignment_path(organization, assignment)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Edit Assignment')
        expect(response.body).to include(assignment.title)
        # This test will catch HAML syntax errors like indentation issues
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/assignments/:id' do
    let(:update_params) do
      {
        assignment: {
          title: 'Updated Assignment',
          tagline: assignment.tagline,
          version_type: 'clarifying'
        }
      }
    end

    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        patch organization_assignment_path(organization, assignment), params: update_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(assignment.reload.title).not_to eq('Updated Assignment')
      end
    end

    context 'when user is manager with employment permissions' do
      before do
        manager_teammate
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'allows access and updates assignment' do
        patch organization_assignment_path(organization, assignment), params: update_params
        expect(response).to have_http_status(:redirect)
        assignment.reload
        expect(response).to redirect_to(organization_assignment_path(organization, assignment))
        expect(flash[:notice]).to eq('Assignment was successfully updated.')
        expect(assignment.title).to eq('Updated Assignment')
      end

      it 'redirects to edit page with flash alert on validation failure' do
        invalid_params = {
          assignment: {
            title: '', # Invalid: title is required
            tagline: assignment.tagline,
            version_type: 'clarifying'
          }
        }
        
        patch organization_assignment_path(organization, assignment), params: invalid_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(edit_organization_assignment_path(organization, assignment))
        expect(flash[:alert]).to be_present
        expect(flash[:alert]).to include('Failed to update assignment')
        expect(assignment.reload.title).not_to eq('')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access and updates assignment' do
        patch organization_assignment_path(organization, assignment), params: update_params
        expect(response).to have_http_status(:redirect)
        assignment.reload
        expect(response).to redirect_to(organization_assignment_path(organization, assignment))
        expect(flash[:notice]).to eq('Assignment was successfully updated.')
        expect(assignment.title).to eq('Updated Assignment')
      end

      it 'redirects to edit page with flash alert on validation failure' do
        invalid_params = {
          assignment: {
            title: '', # Invalid: title is required
            tagline: assignment.tagline,
            version_type: 'clarifying'
          }
        }
        
        patch organization_assignment_path(organization, assignment), params: invalid_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(edit_organization_assignment_path(organization, assignment))
        expect(flash[:alert]).to be_present
        expect(flash[:alert]).to include('Failed to update assignment')
        expect(assignment.reload.title).not_to eq('')
      end
    end
  end

  describe 'DELETE /organizations/:organization_id/assignments/:id' do
    let!(:assignment_to_delete) { create(:assignment, company: organization) }

    context 'when user is a regular teammate' do
      before do
        person_teammate
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        delete organization_assignment_path(organization, assignment_to_delete)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(Assignment.exists?(assignment_to_delete.id)).to be true
      end
    end

    context 'when user is manager with employment permissions' do
      let(:manager_without_maap) { create(:teammate, person: manager, organization: organization, can_manage_employment: true, can_manage_maap: false) }
      
      before do
        manager_without_maap
        sign_in_as_teammate_for_request(manager, organization)
      end

      it 'denies access (only admins can destroy)' do
        delete organization_assignment_path(organization, assignment_to_delete)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(Assignment.exists?(assignment_to_delete.id)).to be true
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access and destroys assignment' do
        expect {
          delete organization_assignment_path(organization, assignment_to_delete)
        }.to change(Assignment, :count).by(-1)
        
        expect(response).to have_http_status(:redirect)
        expect(Assignment.exists?(assignment_to_delete.id)).to be false
      end
    end
  end

  describe 'GET /organizations/:organization_id/assignments with major_version filter' do
    let!(:assignment_v1) { create(:assignment, company: organization, semantic_version: '1.0.0', title: 'Assignment v1') }
    let!(:assignment_v1_2) { create(:assignment, company: organization, semantic_version: '1.2.3', title: 'Assignment v1.2') }
    let!(:assignment_v2) { create(:assignment, company: organization, semantic_version: '2.0.0', title: 'Assignment v2') }
    let!(:assignment_v0) { create(:assignment, company: organization, semantic_version: '0.1.0', title: 'Assignment v0') }

    before do
      person_teammate
      sign_in_as_teammate_for_request(person, organization)
    end

    it 'filters by major version 1' do
      get organization_assignments_path(organization, major_version: 1)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment v1')
      expect(response.body).to include('Assignment v1.2')
      expect(response.body).not_to include('Assignment v2')
      expect(response.body).not_to include('Assignment v0')
    end

    it 'filters by major version 2' do
      get organization_assignments_path(organization, major_version: 2)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment v2')
      expect(response.body).not_to include('Assignment v1')
      expect(response.body).not_to include('Assignment v1.2')
      expect(response.body).not_to include('Assignment v0')
    end

    it 'filters by major version 0' do
      get organization_assignments_path(organization, major_version: 0)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment v0')
      expect(response.body).not_to include('Assignment v1')
      expect(response.body).not_to include('Assignment v1.2')
      expect(response.body).not_to include('Assignment v2')
    end

    it 'shows all assignments when major_version is empty' do
      get organization_assignments_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Assignment v1')
      expect(response.body).to include('Assignment v1.2')
      expect(response.body).to include('Assignment v2')
      expect(response.body).to include('Assignment v0')
    end
  end
end

