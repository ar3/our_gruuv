require 'rails_helper'

RSpec.describe 'Organizations::Aspirations', type: :request do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:maap_user) { create(:person) }
  let(:aspiration) { create(:aspiration, organization: organization) }

  let(:person_teammate) { create(:teammate, person: person, organization: organization, can_manage_maap: false) }
  let(:maap_user_teammate) { create(:teammate, person: maap_user, organization: organization, can_manage_maap: true) }
  let(:admin_teammate) { create(:teammate, person: admin, organization: organization) }

  before do
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
        person_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'allows access to index' do
        get organization_aspirations_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Aspirations')
      end
    end

    context 'when user has MAAP permissions' do
      before do
        maap_user_teammate # Ensure teammate is created with can_manage_maap: true
        sign_in_as_teammate_for_request(maap_user, organization)
      end

      it 'allows access to index' do
        get organization_aspirations_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Aspirations')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(admin, organization)
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
        person_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'allows access to show' do
        get organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(aspiration.name)
      end
    end

    context 'when user has MAAP permissions' do
      before do
        maap_user_teammate # Ensure teammate is created with can_manage_maap: true
        sign_in_as_teammate_for_request(maap_user, organization)
      end

      it 'allows access to show' do
        get organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:success)
        expect(response.body).to include(aspiration.name)
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(admin, organization)
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
        person_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        get new_organization_aspiration_path(organization)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user has MAAP permissions' do
      before do
        maap_user_teammate # Ensure teammate is created with can_manage_maap: true
        sign_in_as_teammate_for_request(maap_user, organization)
      end

      it 'allows access' do
        get new_organization_aspiration_path(organization)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('New Aspiration')
      end
    end

    context 'when user is admin' do
      before do
        # Ensure admin person has og_admin set
        admin.update!(og_admin: true) unless admin.og_admin?
        admin_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(admin, organization)
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
          description: 'Test Description',
          sort_order: 1,
          organization_id: organization.id,
          version_type: 'ready'
        }
      }
    end

    let(:valid_params_without_version) do
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
        person_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        post organization_aspirations_path(organization), params: valid_params
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user has MAAP permissions' do
      before do
        maap_user_teammate # Ensure teammate is created with can_manage_maap: true
        sign_in_as_teammate_for_request(maap_user, organization)
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
        admin_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(admin, organization)
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
        person_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(person, organization)
      end

      it 'denies access' do
        get edit_organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when user has MAAP permissions' do
      before do
        maap_user_teammate # Ensure teammate is created with can_manage_maap: true
        sign_in_as_teammate_for_request(maap_user, organization)
      end

      it 'allows access' do
        get edit_organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Edit Aspiration')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(admin, organization)
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
          description: 'Updated description',
          version_type: 'clarifying'
        }
      }
    end

    context 'when user is a regular teammate' do
      before do
        person_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(person, organization)
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
        maap_user_teammate # Ensure teammate is created with can_manage_maap: true
        sign_in_as_teammate_for_request(maap_user, organization)
      end

      it 'allows access and updates aspiration' do
        patch organization_aspiration_path(organization, aspiration), params: update_params
        expect(response).to have_http_status(:redirect)
        expect(aspiration.reload.name).to eq('Updated Aspiration')
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(admin, organization)
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
        person_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(person, organization)
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
        maap_user_teammate # Ensure teammate is created with can_manage_maap: true
        sign_in_as_teammate_for_request(maap_user, organization)
      end

      it 'allows access and soft deletes aspiration' do
        delete organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:redirect)
        expect(aspiration.reload.deleted_at).not_to be_nil
      end
    end

    context 'when user is admin' do
      before do
        admin_teammate # Ensure teammate is created
        sign_in_as_teammate_for_request(admin, organization)
      end

      it 'allows access and soft deletes aspiration' do
        delete organization_aspiration_path(organization, aspiration)
        expect(response).to have_http_status(:redirect)
        expect(aspiration.reload.deleted_at).not_to be_nil
      end
    end
  end
end
