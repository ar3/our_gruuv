require 'rails_helper'

RSpec.describe Organizations::PublicMaap::PositionsController, type: :controller do
  let(:company) { create(:organization) }
  let(:department) { create(:department, company: company) }
  let(:team) { create(:team, company: company) }
  let(:position_major_level) { create(:position_major_level) }
  
  let!(:position_company) do
    title = create(:title, company: company, position_major_level: position_major_level, external_title: 'Company Position Type')
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, title: title, position_level: position_level)
  end

  let!(:position_department) do
    title = create(:title, company: company, department: department, position_major_level: position_major_level, external_title: 'Department Position Type')
    position_level = create(:position_level, position_major_level: position_major_level)
    create(:position, title: title, position_level: position_level)
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

    it 'groups positions by department' do
      get :index, params: { organization_id: company.id }
      positions_by_org = assigns(:positions_by_org)
      
      # Positions are grouped by department (nil key = company-level positions)
      expect(positions_by_org[nil]).to include(position_company)
      expect(positions_by_org[department]).to include(position_department)
    end

    # Note: This test was removed because Teams are no longer Organizations (STI removed).
    # Titles belong to Organizations and optionally to Departments.
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

