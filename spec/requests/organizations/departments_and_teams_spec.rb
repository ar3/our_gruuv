require 'rails_helper'

RSpec.describe 'Organizations::DepartmentsAndTeams#index', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: organization) }
  let(:team) { create(:organization, :team, parent: department) }
  let(:current_person) { create(:person) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(current_person)
    allow_any_instance_of(Organizations::DepartmentsAndTeamsController).to receive(:organization).and_return(organization)
  end

  describe 'GET /organizations/:id/departments_and_teams' do
    it 'renders the index page without company? method error' do
      # Create the hierarchy
      department
      team
      
      get organization_departments_and_teams_path(organization)
      
      expect(response).to be_successful
      expect(response.body).to include('Departments & Teams')
    end

    it 'displays hierarchy correctly' do
      department
      team
      
      get organization_departments_and_teams_path(organization)
      
      expect(response.body).to include(department.name)
      expect(response.body).to include(team.name)
    end

    it 'handles empty hierarchy gracefully' do
      get organization_departments_and_teams_path(organization)
      
      expect(response).to be_successful
      expect(response.body).to include('No Departments or Teams Created')
    end
  end
end
