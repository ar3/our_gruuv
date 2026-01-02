require 'rails_helper'

RSpec.describe Organizations::CompanyTeammates::OneOnOneLinksController, type: :controller do
  let(:organization) { create(:organization, :company) }
  let(:manager) { create(:person, full_name: 'Manager Person') }
  let(:employee) { create(:person, full_name: 'Employee Person') }
  let(:manager_teammate) { create(:teammate, type: 'CompanyTeammate', person: manager, organization: organization, can_manage_employment: true) }
  let(:employee_teammate) { create(:teammate, person: employee, organization: organization) }
  let(:position_type) { create(:position_type, organization: organization) }
  let(:position_level) { create(:position_level, position_major_level: position_type.position_major_level) }
  let(:position) { create(:position, position_type: position_type, position_level: position_level) }
  let(:employment_tenure) do
    employee_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: employee_teammate, company: organization, manager_teammate: CompanyTeammate.find(manager_teammate.id), position: position)
  end

  before do
    # Set up employment relationship
    manager_teammate.update!(first_employed_at: 1.year.ago)
    create(:employment_tenure, teammate: manager_teammate, company: organization, position: position, started_at: 1.year.ago, ended_at: nil)
    employment_tenure
    # Ensure manager teammate exists and is signed in
    sign_in_as_teammate(manager, organization)
  end

  describe 'GET #show' do
    it 'shows existing one-on-one link' do
      one_on_one_link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://example.com')
      
      get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:one_on_one_link)).to eq(one_on_one_link)
    end

    it 'shows new one-on-one link form when none exists' do
      get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
      
      expect(response).to have_http_status(:success)
      expect(assigns(:one_on_one_link)).to be_a_new(OneOnOneLink)
      expect(assigns(:one_on_one_link).teammate.id).to eq(employee_teammate.id)
    end

    context 'with Asana link' do
      let(:one_on_one_link) do
        link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://app.asana.com/0/123456/789')
        link.deep_integration_config = { 'asana_project_id' => '123456' }
        link.save
        link
      end
      let(:asana_identity) { create(:teammate_identity, :asana, teammate: manager_teammate) }

      before do
        one_on_one_link
        asana_identity
      end

      it 'checks project access when viewing user has Asana identity' do
        service = instance_double(AsanaService)
        allow(AsanaService).to receive(:new).and_return(service)
        allow(service).to receive(:authenticated?).and_return(true)
        allow(service).to receive(:fetch_project).with('123456').and_return({ 'gid' => '123456', 'name' => 'Test Project' })
        allow(service).to receive(:fetch_project_sections).with('123456').and_return({
          success: true,
          sections: []
        })

        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:has_project_access)).to be true
      end

      it 'sets has_project_access to false when access is denied' do
        service = instance_double(AsanaService)
        allow(AsanaService).to receive(:new).and_return(service)
        allow(service).to receive(:authenticated?).and_return(true)
        allow(service).to receive(:fetch_project).with('123456').and_return(nil)
        allow(service).to receive(:fetch_project_sections).with('123456').and_return({
          success: false,
          error: 'permission_denied',
          message: 'Permission denied'
        })

        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:has_project_access)).to be false
      end

      it 'does not check access when viewing user has no Asana identity' do
        asana_identity.destroy

        get :show, params: { organization_id: organization.id, company_teammate_id: employee_teammate.id }
        
        expect(response).to have_http_status(:success)
        expect(assigns(:has_project_access)).to be_nil
      end
    end
  end

  describe 'PATCH #update' do
    it 'creates new one-on-one link' do
      expect {
        patch :update, params: {
          organization_id: organization.id,
          company_teammate_id: employee_teammate.id,
          one_on_one_link: { url: 'https://example.com' }
        }
      }.to change(OneOnOneLink, :count).by(1)
      
      expect(response).to redirect_to(organization_company_teammate_one_on_one_link_path(organization, employee_teammate))
      expect(flash[:notice]).to include('updated successfully')
    end

    it 'updates existing one-on-one link' do
      one_on_one_link = create(:one_on_one_link, teammate: employee_teammate, url: 'https://old-url.com')
      
      patch :update, params: {
        organization_id: organization.id,
        company_teammate_id: employee_teammate.id,
        one_on_one_link: { url: 'https://new-url.com' }
      }
      
      expect(response).to redirect_to(organization_company_teammate_one_on_one_link_path(organization, employee_teammate))
      expect(flash[:notice]).to include('updated successfully')
      expect(one_on_one_link.reload.url).to eq('https://new-url.com')
    end

    it 'validates URL format' do
      patch :update, params: {
        organization_id: organization.id,
        company_teammate_id: employee_teammate.id,
        one_on_one_link: { url: 'invalid-url' }
      }
      
      expect(response).to have_http_status(:unprocessable_entity)
      expect(assigns(:one_on_one_link).errors[:url]).to be_present
    end
  end
end

