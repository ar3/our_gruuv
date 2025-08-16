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
end

