require 'rails_helper'

RSpec.describe Organizations::CompanyTeammatesController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:person) { create(:person) }
  let(:current_access) { create(:teammate, person: person, organization: organization) }

  before do
    # Grant manager permissions
    manager_teammate = create(:teammate, 
           person: manager, 
           organization: organization,
           can_manage_employment: true)
    
    # Create employment tenure for manager in the organization
    create(:employment_tenure, teammate: manager_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    manager_teammate.update!(first_employed_at: 1.year.ago)
    
    # Set up session for authentication
    sign_in_as_teammate(manager, organization)
  end

  describe 'POST #update_permission' do
    context 'when user has manager permissions' do
      it 'updates employment management permission' do
        post :update_permission, params: { 
          organization_id: organization.id,
          id: current_access.id, 
          permission_type: 'can_manage_employment', 
          permission_value: 'true' 
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_company_teammate_path(organization, current_access))
        
        # Verify the permission was updated
        person.reload
        access = person.teammates.find_by(organization: organization)
        expect(access.can_manage_employment).to be true
      end

      it 'updates employment creation permission' do
        post :update_permission, params: { 
          organization_id: organization.id,
          id: current_access.id, 
          permission_type: 'can_create_employment', 
          permission_value: 'false' 
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_company_teammate_path(organization, current_access))
        
        # Verify the permission was updated
        person.reload
        access = person.teammates.find_by(organization: organization)
        expect(access.can_create_employment).to be false
      end

      it 'updates MAAP management permission' do
        post :update_permission, params: { 
          organization_id: organization.id,
          id: current_access.id, 
          permission_type: 'can_manage_maap', 
          permission_value: 'nil' 
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_company_teammate_path(organization, current_access))
        
        # Verify the permission was updated
        person.reload
        access = person.teammates.find_by(organization: organization)
        expect(access.can_manage_maap).to be_nil
      end

      it 'updates prompts management permission' do
        post :update_permission, params: {
          organization_id: organization.id,
          id: current_access.id,
          permission_type: 'can_manage_prompts',
          permission_value: 'true'
        }

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_company_teammate_path(organization, current_access))

        # Verify the permission was updated
        person.reload
        access = person.teammates.find_by(organization: organization)
        expect(access.can_manage_prompts).to be true
      end

      it 'creates teammate record if it does not exist when updating permission' do
        # Ensure no teammate exists for this person/organization
        person.teammates.where(organization: organization).destroy_all

        expect {
          post :update_permission, params: {
            organization_id: organization.id,
            id: current_access.id,
            permission_type: 'can_manage_prompts',
            permission_value: 'true'
          }
        }.to change { person.teammates.where(organization: organization).count }.from(0).to(1)

        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_company_teammate_path(organization, current_access))

        # Verify the permission was updated
        person.reload
        access = person.teammates.find_by(organization: organization)
        expect(access).to be_present
        expect(access.can_manage_prompts).to be true
        # Verify the type is set correctly based on organization type
        expect(access.type).to eq('CompanyTeammate') if organization.type == 'Company'
      end

      it 'handles invalid permission type' do
        post :update_permission, params: { 
          organization_id: organization.id,
          id: current_access.id, 
          permission_type: 'invalid_permission', 
          permission_value: 'true' 
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_company_teammate_path(organization, current_access))
        expect(flash[:alert]).to eq('Invalid permission type.')
      end
    end

    context 'when user lacks manager permissions' do
      before do
        # Remove manager permissions
        manager.teammates.destroy_all
      end

      it 'handles authorization failure' do
        post :update_permission, params: { 
          organization_id: organization.id,
          id: current_access.id, 
          permission_type: 'can_manage_employment', 
          permission_value: 'true' 
        }
        
        # Should redirect (not raise error) when authorization fails
        expect(response).to have_http_status(:redirect)
        # The exact redirect path may vary based on authorization failure handling
      end
    end
  end

  describe 'GET #show' do
    it 'sets @organization (via base controller)' do
      get :show, params: {
        organization_id: organization.id,
        id: current_access.id
      }

      expect(assigns(:organization)).to be_present
      expect(assigns(:organization).id).to eq(organization.id)
    end
  end

  describe 'route accessibility' do
    it 'has the correct route' do
      expect(post: "/organizations/#{organization.id}/company_teammates/#{current_access.id}/update_permission").to route_to(
        controller: 'organizations/company_teammates',
        action: 'update_permission',
        organization_id: organization.id.to_s,
        id: current_access.id.to_s
      )
    end

    it 'generates the correct route helper' do
      # Organization routes include slug format: id-name-parameterized
      expected_path = "/organizations/#{organization.to_param}/company_teammates/#{current_access.id}/update_permission"
      expect(update_permission_organization_company_teammate_path(organization, current_access)).to eq(expected_path)
    end
  end
end
