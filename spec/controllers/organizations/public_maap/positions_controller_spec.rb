require 'rails_helper'

RSpec.describe Organizations::PublicMaap::PositionsController, type: :controller do
  let(:company) { create(:organization, :company) }
  let(:department) { create(:organization, :department, parent: company) }
  let(:team) { create(:organization, :team, parent: department) }
  let(:position_major_level) { create(:position_major_level) }
  
  let!(:position_company) do
    position_type = create(:position_type, organization: company, position_major_level: position_major_level, external_title: 'Company Position Type')
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, position_type: position_type, position_level: position_level)
  end

  let!(:position_department) do
    position_type = create(:position_type, organization: department, position_major_level: position_major_level, external_title: 'Department Position Type')
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, position_type: position_type, position_level: position_level)
  end

  describe 'GET #index' do
    it 'renders successfully without authentication' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'shows all positions' do
      get :index, params: { organization_id: company.id }
      positions = assigns(:positions)
      
      expect(positions).to include(position_company)
      expect(positions).to include(position_department)
    end

    it 'groups positions by organization' do
      get :index, params: { organization_id: company.id }
      positions_by_org = assigns(:positions_by_org)
      
      # Find the organization key in the hash (may be Company/Department instance due to STI)
      company_key = positions_by_org.keys.find { |org| org.id == company.id }
      department_key = positions_by_org.keys.find { |org| org.id == department.id }
      
      expect(positions_by_org[company_key]).to include(position_company)
      expect(positions_by_org[department_key]).to include(position_department)
    end

    it 'excludes teams from hierarchy' do
      # Teams can't have position types, so we'll verify that positions in teams aren't included
      # by checking that only company and department positions are returned
      get :index, params: { organization_id: company.id }
      positions = assigns(:positions)
      
      # All positions should belong to company or department, not teams
      position_orgs = positions.map { |pos| pos.position_type.organization }
      team_orgs = position_orgs.select(&:team?)
      
      expect(team_orgs).to be_empty
    end
  end

  describe 'GET #show' do
    it 'renders successfully without authentication' do
      get :show, params: { organization_id: company.id, id: position_company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the position' do
      get :show, params: { organization_id: company.id, id: position_company.id }
      expect(assigns(:position)).to eq(position_company)
    end

    it 'handles id-name-parameterized format' do
      param = position_company.to_param
      get :show, params: { organization_id: company.id, id: param }
      expect(assigns(:position)).to eq(position_company)
    end

    it 'raises error for invalid position' do
      expect {
        get :show, params: { organization_id: company.id, id: '999999' }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end

