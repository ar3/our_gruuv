require 'rails_helper'

RSpec.describe Organizations::TeammateMilestonesController, type: :controller do
  render_views

  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:ability) { create(:ability, organization: organization, created_by: person, updated_by: person) }

  before do
    sign_in_as_teammate(person, organization)
  end

  let(:teammate) { person.teammates.find_by(organization: organization) }

  describe 'GET #new' do
    it 'renders the new page' do
      get :new, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
    end

    it 'loads teammate data when teammate_id is provided' do
      get :new, params: { organization_id: organization.id, teammate_id: teammate.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:teammate)).to eq(teammate)
      expect(assigns(:teammate_display)).to be_present
    end

    it 'loads ability data when ability_id is provided' do
      get :new, params: { organization_id: organization.id, teammate_id: teammate.id, ability_id: ability.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:ability)).to eq(ability)
      expect(assigns(:ability_data)).to be_present
    end

    it 'includes required assignments from position required assignments in ability_data' do
      # Ensure teammate has first_employed_at set so they're considered employed
      teammate.update!(first_employed_at: 1.month.ago)
      
      # Create a position with required assignments
      position_type = create(:position_type, organization: organization)
      position_level = create(:position_level, position_major_level: position_type.position_major_level)
      
      # Create employment tenure (factory will create a position)
      employment_tenure = create(:employment_tenure, 
             teammate: teammate, 
             company: organization,
             started_at: 1.month.ago,
             ended_at: nil)
      
      position = employment_tenure.position
      
      # Create an assignment with ability requirement
      assignment = create(:assignment, company: organization)
      assignment_ability = create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
      
      # Make this assignment required for the position
      create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
      
      get :new, params: { organization_id: organization.id, teammate_id: teammate.id, ability_id: ability.id }
      
      expect(response).to have_http_status(:success)
      ability_data = assigns(:ability_data)
      expect(ability_data).to be_present
      expect(ability_data[:required_assignments]).to be_present
      
      # Verify that required_assignments includes the assignment from position's required assignments
      assignment_found = ability_data[:required_assignments].any? { |ra| ra[:assignment].id == assignment.id }
      expect(assignment_found).to eq(true)
      expect(ability_data[:required_assignments].find { |ra| ra[:assignment].id == assignment.id }[:milestone_level]).to eq(2)
    end

    it 'displays required assignment pills on the new page' do
      # Ensure teammate has first_employed_at set
      teammate.update!(first_employed_at: 1.month.ago)
      
      # Create assignment with ability requirement at level 1 (so it shows for milestone 1+)
      assignment = create(:assignment, company: organization, title: 'Test Assignment')
      create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 1)
      
      # Create assignment tenure
      create(:assignment_tenure, teammate: teammate, assignment: assignment, started_at: 1.month.ago, ended_at: nil)
      
      get :new, params: { organization_id: organization.id, teammate_id: teammate.id, ability_id: ability.id }
      
      expect(response).to have_http_status(:success)
      # Check that the required assignment pill is displayed inside the collapsed details section
      expect(response.body).to include('Required Milestone 1 for Test Assignment')
      # Check that it's in the assignment requirements section
      expect(response.body).to include('Assignment Requirements:')
    end

    it 'displays milestone details collapse section on the new page' do
      # Set milestone description
      ability.update!(milestone_1_description: 'This is milestone 1 description')
      
      get :new, params: { organization_id: organization.id, teammate_id: teammate.id, ability_id: ability.id }
      
      expect(response).to have_http_status(:success)
      # Check that the collapse button is present
      expect(response.body).to include('Show milestone details')
      # Check that the milestone description is present in the collapse section
      expect(response.body).to include('This is milestone 1 description')
    end

    it 'displays "This Milestone has not been defined" when milestone description is blank' do
      # Ensure milestone description is blank
      ability.update!(milestone_1_description: nil)
      
      get :new, params: { organization_id: organization.id, teammate_id: teammate.id, ability_id: ability.id }
      
      expect(response).to have_http_status(:success)
      # Check that the fallback message is present
      expect(response.body).to include('This Milestone has not been defined')
    end
  end

  describe 'GET #select_teammate' do
    it 'renders the select_teammate page with overlay layout' do
      get :select_teammate, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'loads eligible teammates' do
      # Give current teammate manage_employment permission so they can see all teammates
      teammate.update!(can_manage_employment: true)
      
      other_person = create(:person)
      create(:teammate, person: other_person, organization: organization)
      
      get :select_teammate, params: { organization_id: organization.id }
      expect(assigns(:eligible_teammates)).to be_present
    end
  end

  describe 'GET #select_ability' do
    it 'renders the select_ability page with overlay layout' do
      get :select_ability, params: { organization_id: organization.id, teammate_id: teammate.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'redirects if teammate not found' do
      get :select_ability, params: { organization_id: organization.id, teammate_id: 99999 }
      expect(response).to redirect_to(new_organization_teammate_milestone_path(organization))
      expect(flash[:alert]).to be_present
    end

    it 'includes abilities from position required assignments in required_milestones' do
      # Ensure ability is created with proper organization and creators
      ability.update!(organization: organization, created_by: person, updated_by: person)
      
      # Ensure teammate has first_employed_at set so they're considered employed
      teammate.update!(first_employed_at: 1.month.ago)
      
      # Create a position with required assignments
      # Note: employment_tenure factory creates its own position, so we'll use that position
      position_type = create(:position_type, organization: organization)
      position_level = create(:position_level, position_major_level: position_type.position_major_level)
      
      # Create employment tenure first (factory will create a position)
      employment_tenure = create(:employment_tenure, 
             teammate: teammate, 
             company: organization,
             started_at: 1.month.ago,
             ended_at: nil)
      
      # Use the position created by the factory
      position = employment_tenure.position
      
      # Create an assignment with ability requirement
      assignment = create(:assignment, company: organization)
      assignment_ability = create(:assignment_ability, assignment: assignment, ability: ability, milestone_level: 2)
      
      # Make this assignment required for the position
      position_assignment = create(:position_assignment, position: position, assignment: assignment, assignment_type: 'required')
      
      # Verify the setup
      expect(employment_tenure.active?).to be true
      expect(position.required_assignments.count).to eq(1)
      expect(position.required_assignments.first.assignment).to eq(assignment)
      expect(assignment.assignment_abilities.count).to eq(1)
      
      # Verify active_employment_tenure association can find the tenure
      active_tenure = teammate.active_employment_tenure
      expect(active_tenure).to be_present, "active_employment_tenure should find the employment tenure"
      expect(active_tenure.position).to eq(position)
      
      get :select_ability, params: { organization_id: organization.id, teammate_id: teammate.id }
      
      expect(response).to have_http_status(:success)
      abilities_data = assigns(:abilities_data)
      
      # The ability should be found because it's required by the position
      expect(abilities_data).to be_present, "abilities_data should not be empty - position has required assignment with ability"
      
      # Find the ability in the abilities_data
      ability_data = abilities_data.find { |ad| ad[:ability].id == ability.id }
      expect(ability_data).to be_present, "Ability #{ability.id} should be in abilities_data from position's required assignments"
      
      # Verify that required_milestones includes the assignment from position's required assignments
      expect(ability_data[:required_milestones]).to be_present
      assignment_found = ability_data[:required_milestones].any? { |rm| rm[:assignment].id == assignment.id }
      expect(assignment_found).to eq(true), "Required milestones should include assignment #{assignment.id} from position's required assignments"
      expect(ability_data[:required_milestones].find { |rm| rm[:assignment].id == assignment.id }[:milestone_level]).to eq(2)
    end
  end

  describe 'POST #create' do
    let(:other_person) { create(:person) }
    let(:other_teammate) do
      create(:teammate, person: other_person, organization: organization)
    end
    let(:certifier) { person }

    it 'creates a teammate milestone' do
      expect {
        post :create, params: {
          organization_id: organization.id,
          teammate_id: other_teammate.id,
          ability_id: ability.id,
          milestone_level: 1
        }
      }.to change(TeammateMilestone, :count).by(1)
    end

    it 'creates an observable moment' do
      expect {
        post :create, params: {
          organization_id: organization.id,
          teammate_id: other_teammate.id,
          ability_id: ability.id,
          milestone_level: 1
        }
      }.to change(ObservableMoment, :count).by(1)
    end

    it 'redirects to the show page on success' do
      post :create, params: {
        organization_id: organization.id,
        teammate_id: other_teammate.id,
        ability_id: ability.id,
        milestone_level: 1
      }
      
      milestone = TeammateMilestone.last
      expect(response).to redirect_to(organization_teammate_milestone_path(organization, milestone))
      expect(flash[:notice]).to be_present
    end

    it 'does not create duplicate milestones' do
      # Use the existing teammate for the certifier (person is already a teammate)
      certifier_teammate = teammate
      create(:teammate_milestone, teammate: other_teammate, ability: ability, milestone_level: 1, certifying_teammate: certifier_teammate)
      
      expect {
        post :create, params: {
          organization_id: organization.id,
          teammate_id: other_teammate.id,
          ability_id: ability.id,
          milestone_level: 1
        }
      }.not_to change(TeammateMilestone, :count)
      
      expect(response).to redirect_to(new_organization_teammate_milestone_path(organization, teammate_id: other_teammate.id, ability_id: ability.id))
      expect(flash[:alert]).to be_present
    end
  end

  describe 'GET #show' do
    let(:teammate_milestone) do
      create(:teammate_milestone, 
             teammate: teammate, 
             ability: ability, 
             certifying_teammate: teammate,
             attained_at: Date.current)
    end

    it 'renders the show page' do
      get :show, params: { organization_id: organization.id, id: teammate_milestone.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:teammate_milestone)).to eq(teammate_milestone)
    end

    it 'loads observable moment if it exists' do
      observable_moment = ObservableMoments::BaseObservableMomentService.call(
        momentable: teammate_milestone,
        company: organization,
        created_by: person,
        primary_potential_observer: teammate,
        moment_type: 'ability_milestone',
        occurred_at: Time.current
      ).value
      
      get :show, params: { organization_id: organization.id, id: teammate_milestone.id }
      expect(assigns(:observable_moment)).to eq(observable_moment)
    end
  end
end

