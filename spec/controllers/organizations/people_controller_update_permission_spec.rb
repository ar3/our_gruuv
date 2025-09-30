require 'rails_helper'

RSpec.describe Organizations::PeopleController, type: :controller do
  let(:organization) { create(:organization) }
  let(:manager) { create(:person) }
  let(:person) { create(:person) }
  let(:current_access) { create(:person_organization_access, person: person, organization: organization) }

  before do
    # Set up session for authentication
    session[:current_person_id] = manager.id
    
    # Create employment tenure for manager in the organization
    create(:employment_tenure, person: manager, company: organization)
    
    # Grant manager permissions
    create(:person_organization_access, 
           person: manager, 
           organization: organization,
           can_manage_employment: true)
  end

  describe 'POST #update_permission' do
    context 'when user has manager permissions' do
      it 'updates employment management permission' do
        post :update_permission, params: { 
          organization_id: organization.id,
          id: person.id, 
          permission_type: 'can_manage_employment', 
          permission_value: 'true' 
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_person_path(organization, person))
        
        # Verify the permission was updated
        person.reload
        access = person.person_organization_accesses.find_by(organization: organization)
        expect(access.can_manage_employment).to be true
      end

      it 'updates employment creation permission' do
        post :update_permission, params: { 
          organization_id: organization.id,
          id: person.id, 
          permission_type: 'can_create_employment', 
          permission_value: 'false' 
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_person_path(organization, person))
        
        # Verify the permission was updated
        person.reload
        access = person.person_organization_accesses.find_by(organization: organization)
        expect(access.can_create_employment).to be false
      end

      it 'updates MAAP management permission' do
        post :update_permission, params: { 
          organization_id: organization.id,
          id: person.id, 
          permission_type: 'can_manage_maap', 
          permission_value: 'nil' 
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_person_path(organization, person))
        
        # Verify the permission was updated
        person.reload
        access = person.person_organization_accesses.find_by(organization: organization)
        expect(access.can_manage_maap).to be_nil
      end

      it 'handles invalid permission type' do
        post :update_permission, params: { 
          organization_id: organization.id,
          id: person.id, 
          permission_type: 'invalid_permission', 
          permission_value: 'true' 
        }
        
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_person_path(organization, person))
        expect(flash[:alert]).to eq('Invalid permission type.')
      end
    end

    context 'when user lacks manager permissions' do
      before do
        # Remove manager permissions
        manager.person_organization_accesses.destroy_all
      end

      it 'handles authorization failure' do
        post :update_permission, params: { 
          organization_id: organization.id,
          id: person.id, 
          permission_type: 'can_manage_employment', 
          permission_value: 'true' 
        }
        
        # Should redirect (not raise error) when authorization fails
        expect(response).to have_http_status(:redirect)
        # The exact redirect path may vary based on authorization failure handling
      end
    end
  end

  describe 'route accessibility' do
    it 'has the correct route' do
      expect(post: "/organizations/#{organization.id}/people/#{person.id}/update_permission").to route_to(
        controller: 'organizations/people',
        action: 'update_permission',
        organization_id: organization.id.to_s,
        id: person.id.to_s
      )
    end

    it 'generates the correct route helper' do
      expect(update_permission_organization_person_path(organization, person)).to eq("/organizations/#{organization.id}/people/#{person.id}/update_permission")
    end
  end
end
