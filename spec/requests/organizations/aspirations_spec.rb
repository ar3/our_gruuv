require 'rails_helper'

RSpec.describe 'Organizations::Aspirations', type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:maap_user) { create(:person) }
  let(:aspiration) { create(:aspiration, organization: organization) }

  before do
    # Grant MAAP permissions to maap_user for organization
    create(:teammate, 
           person: maap_user, 
           organization: organization, 
           can_manage_maap: true)
    
    # Create regular teammate for person
    create(:teammate, 
           person: person, 
           organization: organization, 
           can_manage_maap: false)
    
    # Temporarily disable PaperTrail for request tests to avoid controller_info issues
    PaperTrail.enabled = false
  end

  after do
    # Re-enable PaperTrail after tests
    PaperTrail.enabled = true
  end

  describe 'GET /organizations/:organization_id/aspirations' do
    context 'when user is a regular teammate' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access to index' do
        get organization_aspirations_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Aspirations')
      end
    end

    context 'when user has MAAP permissions' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(maap_user)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access to index' do
        get organization_aspirations_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Aspirations')
      end
    end

    context 'when user is admin' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(admin)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access to index' do
        get organization_aspirations_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Aspirations')
      end
    end
  end

  describe 'GET /organizations/:organization_id/aspirations/:id' do
    context 'when user is a regular teammate' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access to show' do
        get organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(aspiration.name)
      end
    end

    context 'when user has MAAP permissions' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(maap_user)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access to show' do
        get organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(aspiration.name)
      end
    end

    context 'when user is admin' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(admin)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access to show' do
        get organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(aspiration.name)
      end
    end
  end

  describe 'GET /organizations/:organization_id/aspirations/new' do
    context 'when user is a regular teammate' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'denies access' do
        get new_organization_aspiration_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user has MAAP permissions' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(maap_user)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access' do
        get new_organization_aspiration_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New Aspiration')
      end
    end

    context 'when user is admin' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(admin)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access' do
        get new_organization_aspiration_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New Aspiration')
      end
    end
  end

  describe 'POST /organizations/:organization_id/aspirations' do
    let(:valid_params) do
      {
        aspiration: {
          name: 'Test Aspiration',
          description: 'Test description',
          sort_order: 10
        }
      }
    end

    context 'when user is a regular teammate' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'denies access' do
        post organization_aspirations_path(organization), params: valid_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user has MAAP permissions' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(maap_user)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access and creates aspiration' do
        expect {
          post organization_aspirations_path(organization), params: valid_params
        }.to change(Aspiration, :count).by(1)
        
        expect(response).to have_http_status(:redirect)
        expect(Aspiration.last.name).to eq('Test Aspiration')
      end
    end

    context 'when user is admin' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(admin)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access and creates aspiration' do
        expect {
          post organization_aspirations_path(organization), params: valid_params
        }.to change(Aspiration, :count).by(1)
        
        expect(response).to have_http_status(:redirect)
        expect(Aspiration.last.name).to eq('Test Aspiration')
      end
    end
  end

  describe 'GET /organizations/:organization_id/aspirations/:id/edit' do
    context 'when user is a regular teammate' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'denies access' do
        get edit_organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user has MAAP permissions' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(maap_user)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access' do
        get edit_organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Edit Aspiration')
      end
    end

    context 'when user is admin' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(admin)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access' do
        get edit_organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Edit Aspiration')
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/aspirations/:id' do
    let(:update_params) do
      {
        aspiration: {
          name: 'Updated Aspiration',
          description: 'Updated description'
        }
      }
    end

    context 'when user is a regular teammate' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'denies access' do
        patch organization_aspiration_path(organization, aspiration), params: update_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(aspiration.reload.name).not_to eq('Updated Aspiration')
      end
    end

    context 'when user has MAAP permissions' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(maap_user)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access and updates aspiration' do
        patch organization_aspiration_path(organization, aspiration), params: update_params
        expect(response).to have_http_status(:redirect)
        expect(aspiration.reload.name).to eq('Updated Aspiration')
      end
    end

    context 'when user is admin' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(admin)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access and updates aspiration' do
        patch organization_aspiration_path(organization, aspiration), params: update_params
        expect(response).to have_http_status(:redirect)
        expect(aspiration.reload.name).to eq('Updated Aspiration')
      end
    end
  end

  describe 'DELETE /organizations/:organization_id/aspirations/:id' do
    context 'when user is a regular teammate' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'denies access' do
        delete organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
        expect(aspiration.reload.deleted_at).to be_nil
      end
    end

    context 'when user has MAAP permissions' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(maap_user)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access and soft deletes aspiration' do
        delete organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:redirect)
        expect(aspiration.reload.deleted_at).not_to be_nil
      end
    end

    context 'when user is admin' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(admin)
        allow_any_instance_of(ApplicationController).to receive(:current_organization).and_return(organization)
      end

      it 'allows access and soft deletes aspiration' do
        delete organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:redirect)
        expect(aspiration.reload.deleted_at).not_to be_nil
      end
    end
  end
end
