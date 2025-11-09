require 'rails_helper'

RSpec.describe Organizations::DepartmentsAndTeamsController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: organization) }
  let(:team) { create(:organization, :team, parent: department) }
  let(:current_person) { create(:person) }

  before do
    create(:teammate, person: current_person, organization: organization)
    sign_in_as_teammate(current_person, organization)
    allow(controller).to receive(:set_organization).and_return(true)
    controller.instance_variable_set(:@organization, organization)
  end

  describe 'GET #index' do
    it 'loads descendants with proper includes' do
      # Create the hierarchy
      department
      team
      
      get :index, params: { organization_id: organization.id }
      
      expect(response).to be_successful
      expect(assigns(:departments_and_teams)).to be_present
      expect(assigns(:hierarchy)).to be_present
    end

    it 'builds hierarchy correctly with nested organizations' do
      # Create nested structure: Company -> Department -> Team
      department
      team
      
      get :index, params: { organization_id: organization.id }
      
      hierarchy = assigns(:hierarchy)
      expect(hierarchy.length).to eq(1)
      
      department_item = hierarchy.first
      expect(department_item[:organization].id).to eq(department.id)
      expect(department_item[:organization].type).to eq('Department')
      expect(department_item[:level]).to eq(0)
      expect(department_item[:children].length).to eq(1)
      
      team_item = department_item[:children].first
      expect(team_item[:organization].id).to eq(team.id)
      expect(team_item[:organization].type).to eq('Team')
      expect(team_item[:level]).to eq(1)
    end

    it 'handles empty descendants gracefully' do
      get :index, params: { organization_id: organization.id }
      
      expect(response).to be_successful
      expect(assigns(:departments_and_teams)).to be_empty
      expect(assigns(:hierarchy)).to be_empty
    end
  end
end
