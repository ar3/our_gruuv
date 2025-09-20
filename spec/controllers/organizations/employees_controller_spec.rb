require 'rails_helper'

RSpec.describe Organizations::EmployeesController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company) }
  let(:team) { create(:organization, :team, parent: company) }
  let(:employee1) { create(:person) }
  let(:employee2) { create(:person) }
  let(:huddle_participant) { create(:person) }
  let(:position_major_level) { create(:position_major_level, major_level: 1, set_name: 'Engineering') }
  let(:position_type) { create(:position_type, organization: company, position_major_level: position_major_level) }
  let(:position_level) { create(:position_level, position_major_level: position_major_level, level: '1.1') }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:employment_tenure1) { create(:employment_tenure, person: employee1, company: company, position: position, started_at: 1.year.ago) }
  let(:employment_tenure2) { create(:employment_tenure, person: employee2, company: company, position: position, started_at: 6.months.ago) }
  let(:huddle_playbook) { create(:huddle_playbook, organization: team) }
  let(:huddle) { create(:huddle, huddle_playbook: huddle_playbook) }
  let(:huddle_participation) { create(:huddle_participant, huddle: huddle, person: huddle_participant) }

  before do
    session[:current_person_id] = person.id
    employment_tenure1
    employment_tenure2
    huddle_participation
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct variables' do
      get :index, params: { organization_id: company.id }
      
      expect(assigns(:organization).id).to eq(company.id)
      expect(assigns(:active_employees)).to include(employee1, employee2)
      expect(assigns(:huddle_participants)).to include(huddle_participant)
      expect(assigns(:just_huddle_participants)).to include(huddle_participant)
    end

    it 'includes huddle participants from child organizations' do
      get :index, params: { organization_id: company.id }
      
      # Should include participants from child organizations (team)
      expect(assigns(:huddle_participants)).to include(huddle_participant)
    end

    it 'separates active employees from huddle-only participants' do
      get :index, params: { organization_id: company.id }
      
      # Active employees should not be in just_huddle_participants
      expect(assigns(:just_huddle_participants)).not_to include(employee1, employee2)
      # Huddle-only participants should not be in active_employees
      expect(assigns(:active_employees)).not_to include(huddle_participant)
    end

    it 'handles organizations with no employees gracefully' do
      empty_company = create(:organization, :company)
      
      get :index, params: { organization_id: empty_company.id }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:active_employees)).to be_empty
      expect(assigns(:huddle_participants)).to be_empty
    end
  end

  describe 'GET #audit' do
    let(:maap_manager) { create(:person) }
    let(:maap_access) { create(:person_organization_access, person: maap_manager, organization: company, can_manage_maap: true) }
    let(:maap_snapshot1) { create(:maap_snapshot, employee: employee1, created_by: maap_manager, company: company, change_type: 'assignment_management') }
    let(:maap_snapshot2) { create(:maap_snapshot, employee: employee1, created_by: maap_manager, company: company, change_type: 'position_tenure') }

    before do
      maap_access
      maap_snapshot1
      maap_snapshot2
    end

    context 'when user has MAAP management permissions' do
      before do
        session[:current_person_id] = maap_manager.id
      end

      it 'returns http success' do
        get :audit, params: { organization_id: company.id, id: employee1.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns the correct variables' do
        get :audit, params: { organization_id: company.id, id: employee1.id }
        
        expect(assigns(:person)).to eq(employee1)
        expect(assigns(:maap_snapshots)).to include(maap_snapshot1, maap_snapshot2)
      end

      it 'only shows MAAP snapshots for the specific organization' do
        other_company = create(:organization, :company)
        other_snapshot = create(:maap_snapshot, employee: employee1, created_by: maap_manager, company: other_company)
        
        get :audit, params: { organization_id: company.id, id: employee1.id }
        
        expect(assigns(:maap_snapshots)).to include(maap_snapshot1, maap_snapshot2)
        expect(assigns(:maap_snapshots)).not_to include(other_snapshot)
      end
    end

    context 'when user does not have MAAP management permissions' do
      let(:unauthorized_user) { create(:person) }
      
      before do
        session[:current_person_id] = unauthorized_user.id
      end

      it 'redirects when authorization fails' do
        get :audit, params: { organization_id: company.id, id: employee1.id }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user is the person themselves' do
      before do
        session[:current_person_id] = employee1.id
      end

      it 'allows access to own audit view' do
        get :audit, params: { organization_id: company.id, id: employee1.id }
        expect(response).to have_http_status(:success)
      end
    end
  end
end

