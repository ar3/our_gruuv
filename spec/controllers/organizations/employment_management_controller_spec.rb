require 'rails_helper'

RSpec.describe Organizations::EmploymentManagementController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person, og_admin: false) }
  let(:position_major_level) { create(:position_major_level) }
  let(:title) { create(:title, organization: organization, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level) }
  let(:position) { create(:position, title: title, position_level: position_level) }
  let(:manager) { create(:person) }
  let!(:manager_teammate) { create(:company_teammate, person: manager, organization: organization) }
  
  before do
    # Set up organization with positions and managers
    create(:employment_tenure, teammate: manager_teammate, company: organization, position: position)
    
    # Set up person organization access for current user
    person_teammate = create(:teammate, 
           person: person, 
           organization: organization, 
           can_create_employment: true)
    
    # Use existing teammate to avoid duplicate
    session[:current_company_teammate_id] = person_teammate.id
    @current_company_teammate = nil if defined?(@current_company_teammate)
  end
  
  describe 'GET #index' do
    context 'when user has create employment permission' do
      it 'allows access to the index page' do
        get :index, params: { organization_id: organization.id }
        expect(response).to have_http_status(:success)
      end
      
      it 'loads potential employees' do
        # Create a person with access but no employment
        potential_person = create(:person)
        create(:teammate, 
               person: potential_person, 
               organization: organization)
        
        get :index, params: { organization_id: organization.id }
        expect(assigns(:potential_employees)).to include(potential_person)
      end
    end
    
    context 'when user lacks create employment permission' do
      before do
        # Remove the create employment permission but keep the teammate
        teammate = person.teammates.find_by(organization: organization)
        teammate.update!(can_create_employment: false)
        # Verify the permission is actually removed
        expect(Teammate.can_create_employment?(person, organization)).to be false
      end
      
      it 'allows access to view but not create' do
        get :index, params: { organization_id: organization.id }
        expect(response).to have_http_status(:success)
        # Creation permissions are handled in the view, not the controller
      end
    end
  end
  
  describe 'GET #new' do
    context 'when user has create employment permission' do
      it 'allows access to the new page' do
        get :new, params: { organization_id: organization.id }
        expect(response).to have_http_status(:success)
      end
      
      it 'sets up wizard data' do
        get :new, params: { organization_id: organization.id }
        expect(assigns(:positions).pluck(:id)).to eq(organization.positions.pluck(:id))
        expect(assigns(:managers).pluck(:id)).to eq(organization.employees.pluck(:id))
        expect(assigns(:employment_tenure)).to be_a(EmploymentTenure)
      end
    end
  end
  
  describe 'POST #create' do
    let(:valid_person_params) do
      {
        first_name: 'John',
        last_name: 'Doe',
        email: 'john.doe@example.com',
        timezone: 'Eastern Time (US & Canada)'
      }
    end
    
    let(:valid_employment_params) do
      {
        position_id: position.id,
        manager_teammate_id: manager_teammate.id,
        started_at: Date.current,
        employment_change_notes: 'New hire'
      }
    end
    
    context 'when creating employment for existing person' do
      let(:existing_person) { create(:person) }
      
      it 'creates employment for existing person' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            person_id: existing_person.id,
            employment_tenure: valid_employment_params
          }
        }.to change { existing_person.teammates.joins(:employment_tenures).count }.by(1)
        
        expect(response).to redirect_to(organization_company_teammate_path(organization, existing_person.teammates.find_by(organization: organization)))
      end
      
      it 'sets the correct company' do
        post :create, params: {
          organization_id: organization.id,
          person_id: existing_person.id,
          employment_tenure: valid_employment_params
        }
        
        employment = existing_person.teammates.joins(:employment_tenures).first.employment_tenures.last
        expect(employment.company.id).to eq(organization.id)
      end
    end
    
    context 'when creating new person and employment' do
      it 'creates both person and employment' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            person: valid_person_params,
            employment_tenure: valid_employment_params
          }
        }.to change { Person.count }.by(1)
          .and change { EmploymentTenure.count }.by(1)
      end
      
      it 'redirects to person profile when save and continue' do
        post :create, params: {
          organization_id: organization.id,
          person: valid_person_params,
          employment_tenure: valid_employment_params,
          save_and_continue: 'true'
        }
        
        expect(response).to redirect_to(organization_company_teammate_path(organization, Person.last.teammates.find_by(organization: organization)))
      end
      
      it 'redirects back to form when save and create another' do
        post :create, params: {
          organization_id: organization.id,
          person: valid_person_params,
          employment_tenure: valid_employment_params,
          save_and_continue: 'false'
        }
        
        expect(response).to redirect_to(new_organization_employment_management_path(organization))
      end
      
      it 'handles validation errors gracefully' do
        post :create, params: {
          organization_id: organization.id,
          person: { first_name: '' }, # Invalid - missing required fields
          employment_tenure: valid_employment_params
        }
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
    
    context 'when user lacks create employment permission' do
      before do
        # Remove the create employment permission but keep the teammate
        teammate = person.teammates.find_by(organization: organization)
        teammate.update!(can_create_employment: false)
        # Verify the permission is actually removed
        expect(Teammate.can_create_employment?(person, organization)).to be false
      end
      
      it 'denies access' do
        post :create, params: {
          organization_id: organization.id,
          person: valid_person_params,
          employment_tenure: valid_employment_params
        }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to eq("You don't have permission to access that resource. Please contact your administrator if you believe this is an error.")
      end
    end
  end
  
  describe 'GET #potential_employees' do
          it 'returns potential employees as JSON' do
        potential_person = create(:person)
        create(:teammate, 
               person: potential_person, 
               organization: organization)
        
        get :potential_employees, params: { organization_id: organization.id }
        
        expect(response).to have_http_status(:success)
        json_response = JSON.parse(response.body)
        
        # Find the expected person in the response
        expected_person = json_response.find { |p| p['id'] == potential_person.id }
        expect(expected_person).to be_present
        expect(expected_person['name']).to eq(potential_person.display_name)
        expect(expected_person['email']).to eq(potential_person.email)
      end
  end
  
  describe 'private methods' do
    describe '#load_potential_employees' do
      it 'finds people with access but no employment' do
        access_person = create(:person)
        create(:teammate, 
               person: access_person, 
               organization: organization)
        
        # Set up the organization instance variable
        controller.instance_variable_set(:@organization, organization)
        
        potential_employees = controller.send(:load_potential_employees)
        expect(potential_employees).to include(access_person)
      end
      
      it 'finds people with huddle participation but no employment' do
        huddle_person = create(:person)
        huddle_playbook = create(:huddle_playbook, company: organization)
        huddle = create(:huddle, huddle_playbook: huddle_playbook)
        create(:huddle_participant, teammate: create(:teammate, person: huddle_person, organization: organization), huddle: huddle)
        
        # Set up the organization instance variable
        controller.instance_variable_set(:@organization, organization)
        
        potential_employees = controller.send(:load_potential_employees)
        expect(potential_employees).to include(huddle_person)
      end
      
      it 'excludes people who already have employment' do
        employed_person = create(:person)
        create(:employment_tenure, teammate: create(:teammate, person: employed_person, organization: organization), company: organization, position: position)
        
        # Set up the organization instance variable
        controller.instance_variable_set(:@organization, organization)
        
        potential_employees = controller.send(:load_potential_employees)
        expect(potential_employees).not_to include(employed_person)
      end
    end
  end
end
