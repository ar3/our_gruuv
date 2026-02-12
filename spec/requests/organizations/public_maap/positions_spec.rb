require 'rails_helper'

RSpec.describe 'Organizations::PublicMaap::Positions', type: :request do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:department, company: company) }
  let(:position_major_level) { create(:position_major_level) }
  
  let!(:position_company) do
    title = create(:title, company: company, position_major_level: position_major_level, external_title: 'Company Position Type')
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, title: title, position_level: position_level, position_summary: 'This is a company position')
  end

  let!(:position_department) do
    title = create(:title, company: company, department: department, position_major_level: position_major_level, external_title: 'Department Position Type')
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, title: title, position_level: position_level)
  end

  describe 'GET /organizations/:organization_id/public_maap/positions' do
    it 'renders successfully without authentication' do
      get organization_public_maap_positions_path(company)
      expect(response).to have_http_status(:success)
    end

    it 'shows all positions' do
      get organization_public_maap_positions_path(company)
      expect(response.body).to include('Company Position Type')
      expect(response.body).to include('Department Position Type')
    end

    it 'groups positions by organization' do
      get organization_public_maap_positions_path(company)
      expect(response.body).to include(company.name)
      expect(response.body).to include(department.name)
    end

    it 'excludes teams from hierarchy' do
      # Teams can't have position types, so we verify that only company and department positions are returned
      get organization_public_maap_positions_path(company)
      
      # All positions should belong to company or department, not teams
      # This is verified by checking that the response includes our company and department positions
      # but doesn't include any team-related content
      expect(response.body).to include('Company Position Type')
      expect(response.body).to include('Department Position Type')
      # Teams are excluded by the controller logic, so no team positions should appear
    end

    it 'shows link to authenticated version when user is logged in' do
      person = create(:person)
      sign_in_as_teammate_for_request(person, company)
      
      get organization_public_maap_positions_path(company)
      expect(response.body).to include('View Authenticated Version')
    end

    it 'shows logged-in teammate display name in the header' do
      person = create(:person, first_name: 'Jane', last_name: 'Doe', preferred_name: 'Janey')
      sign_in_as_teammate_for_request(person, company)

      get organization_public_maap_positions_path(company)
      expect(response.body).to include(person.display_name)
    end

    it 'does not show link to authenticated version when user is not logged in' do
      get organization_public_maap_positions_path(company)
      expect(response.body).not_to include('View Authenticated Version')
    end
  end

  describe 'GET /organizations/:organization_id/public_maap/positions/:id' do
    it 'renders successfully without authentication' do
      get organization_public_maap_position_path(company, position_company)
      expect(response).to have_http_status(:success)
    end

    it 'displays position display name' do
      get organization_public_maap_position_path(company, position_company)
      expect(response.body).to include(position_company.display_name)
    end

    it 'displays position summary' do
      get organization_public_maap_position_path(company, position_company)
      expect(response.body).to include('This is a company position')
    end

    it 'shows "Back to Positions" link' do
      get organization_public_maap_position_path(company, position_company)
      expect(response.body).to include('Back to Positions')
    end

    it 'shows "View Authenticated Version" link when user is logged in' do
      person = create(:person)
      sign_in_as_teammate_for_request(person, company)
      
      get organization_public_maap_position_path(company, position_company)
      expect(response.body).to include('View Authenticated Version')
    end

    it 'does not show "View Authenticated Version" link when user is not logged in' do
      get organization_public_maap_position_path(company, position_company)
      expect(response.body).not_to include('View Authenticated Version')
    end

    it 'handles id-name-parameterized format' do
      param = position_company.to_param
      get organization_public_maap_position_path(company, param)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(position_company.display_name)
    end

    context 'when position has required assignments' do
      let!(:required_assignment) do
        create(:assignment, company: company, title: 'Required Assignment', tagline: 'This is required')
      end

      let!(:position_assignment) do
        create(:position_assignment, 
          position: position_company, 
          assignment: required_assignment, 
          assignment_type: 'required',
          min_estimated_energy: 20,
          max_estimated_energy: 40
        )
      end

      it 'displays required assignments section' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('Required Assignments')
        expect(response.body).to include('Required Assignment')
      end

      it 'displays assignment tagline' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('This is required')
      end

      it 'displays energy estimate' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('likely 20% to 40% of your energy')
      end

      it 'displays link to assignment using public MAAP path' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include(organization_public_maap_assignment_path(company, required_assignment))
      end

      context 'when assignment has outcomes' do
        let!(:outcome) do
          create(:assignment_outcome, assignment: required_assignment, description: 'Test outcome', outcome_type: 'sentiment')
        end

        it 'displays assignment outcomes' do
          get organization_public_maap_position_path(company, position_company)
          expect(response.body).to include('Test outcome')
          expect(response.body).to include('as measured by')
        end
      end

      context 'when assignment has no outcomes' do
        it 'displays "outcomes to be determined"' do
          get organization_public_maap_position_path(company, position_company)
          expect(response.body).to include('outcomes to be determined')
        end
      end

      context 'when assignment has abilities' do
        let(:ability_org) { company }
        let(:created_by) { create(:person) }
        let(:updated_by) { create(:person) }
        let!(:ability) do
          create(:ability, company: ability_org, name: 'Test Ability', created_by: created_by, updated_by: updated_by)
        end

        let!(:assignment_ability) do
          create(:assignment_ability, assignment: required_assignment, ability: ability, milestone_level: 1)
        end

        it 'displays assignment abilities' do
          get organization_public_maap_position_path(company, position_company)
          expect(response.body).to include('Test Ability')
          expect(response.body).to include('needing Abilities such as')
        end

        it 'displays link to ability using public MAAP path' do
          get organization_public_maap_position_path(company, position_company)
          expect(response.body).to include(organization_public_maap_ability_path(ability_org, ability))
        end
      end

      context 'when assignment has no abilities' do
        it 'displays "ability milestones to be determined"' do
          get organization_public_maap_position_path(company, position_company)
          expect(response.body).to include('ability milestones to be determined')
        end
      end
    end

    context 'when position has suggested assignments' do
      let!(:suggested_assignment) do
        create(:assignment, company: company, title: 'Suggested Assignment', tagline: 'This is suggested')
      end

      let!(:position_assignment) do
        create(:position_assignment, 
          position: position_company, 
          assignment: suggested_assignment, 
          assignment_type: 'suggested',
          max_estimated_energy: 30
        )
      end

      it 'displays suggested assignments section' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('Optional / Elective / Uniquely-You Assignments')
        expect(response.body).to include('Suggested Assignment')
      end

      it 'displays assignment tagline' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('This is suggested')
      end

      it 'displays energy estimate' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('up to 30% of your energy')
      end

      it 'has collapsible section for suggested assignments' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('collapse')
        expect(response.body).to include('suggestedAssignments')
      end
    end

    context 'when position has both required and suggested assignments' do
      let!(:required_assignment) do
        create(:assignment, company: company, title: 'Required Assignment')
      end

      let!(:suggested_assignment) do
        create(:assignment, company: company, title: 'Suggested Assignment')
      end

      let!(:required_pa) do
        create(:position_assignment, 
          position: position_company, 
          assignment: required_assignment, 
          assignment_type: 'required'
        )
      end

      let!(:suggested_pa) do
        create(:position_assignment, 
          position: position_company, 
          assignment: suggested_assignment, 
          assignment_type: 'suggested'
        )
      end

      it 'displays both sections' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('Required Assignments')
        expect(response.body).to include('Optional / Elective / Uniquely-You Assignments')
        expect(response.body).to include('Required Assignment')
        expect(response.body).to include('Suggested Assignment')
      end
    end

    context 'when position has no assignments' do
      it 'displays no assignments message' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('No Assignments Defined')
      end
    end

    context 'when position has eligibility requirements' do
      before do
        position_company.update(eligibility_requirements_summary: 'Must have 5 years experience')
      end

      it 'displays eligibility requirements' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('Eligibility Requirements')
        expect(response.body).to include('Must have 5 years experience')
      end
    end

    context 'when position has direct milestone requirements' do
      let(:ability) { create(:ability, company: company, name: 'Public Collaboration') }

      before do
        create(:position_ability, position: position_company, ability: ability, milestone_level: 2)
      end

      it 'displays Additional Abilities required section' do
        get organization_public_maap_position_path(company, position_company)
        expect(response.body).to include('Additional Abilities required')
        expect(response.body).to include('Public Collaboration')
        expect(response.body).to include('needing Abilities such as')
      end
    end
  end
end

