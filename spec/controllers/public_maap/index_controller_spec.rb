require 'rails_helper'

RSpec.describe PublicMaap::IndexController, type: :controller do
  describe 'GET #index' do
    let!(:company_with_position) do
      company = create(:organization, :company, name: 'Company A')
      position_major_level = create(:position_major_level)
      title = create(:title, company: company, position_major_level: position_major_level)
      position_level = create(:position_level, position_major_level: position_major_level)
      create(:position, title: title, position_level: position_level)
      company
    end

    let!(:company_with_assignment) do
      company = create(:organization, :company, name: 'Company B')
      create(:assignment, company: company)
      company
    end

    let!(:company_with_ability) do
      company = create(:organization, :company, name: 'Company C')
      created_by = create(:person)
      updated_by = create(:person)
      create(:ability, company: company, created_by: created_by, updated_by: updated_by)
      company
    end

    let!(:company_with_aspiration) do
      company = create(:organization, :company, name: 'Company D')
      create(:aspiration, company: company)
      company
    end

    let!(:company_with_no_content) do
      create(:organization, :company, name: 'Company E')
    end

    it 'renders successfully without authentication' do
      get :index
      expect(response).to have_http_status(:success)
    end

    it 'assigns companies with content' do
      get :index
      companies = assigns(:companies)
      
      expect(companies).to include(company_with_position)
      expect(companies).to include(company_with_assignment)
      expect(companies).to include(company_with_ability)
      expect(companies).to include(company_with_aspiration)
      expect(companies).not_to include(company_with_no_content)
    end

    it 'orders companies by name' do
      get :index
      companies = assigns(:companies)
      
      expect(companies.map(&:name)).to eq(['Company A', 'Company B', 'Company C', 'Company D'])
    end
  end
end

