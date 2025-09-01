require 'rails_helper'

RSpec.describe Organizations::AbilitiesController, type: :controller do
  let(:organization) { create(:organization) }
  let(:other_organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:admin) { create(:person, :admin) }
  let(:maap_user) { create(:person) }
  let(:ability) { create(:ability, organization: organization) }

  before do
    # Grant MAAP permissions to maap_user for organization
    create(:person_organization_access, 
           person: maap_user, 
           organization: organization, 
           can_manage_maap: true)
    
    # Set current person and organization
    allow(controller).to receive(:current_person).and_return(maap_user)
    allow(controller).to receive(:current_organization).and_return(organization)
  end

  describe 'GET #index' do
    context 'when user has MAAP permissions' do
      before do
        get :index, params: { organization_id: organization.id }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns abilities for the organization' do
        expect(assigns(:abilities)).to eq(organization.abilities)
      end

      it 'renders index template' do
        expect(response).to render_template(:index)
      end
    end

    context 'when user lacks MAAP permissions' do
      before do
        allow(controller).to receive(:current_person).and_return(person)
        get :index, params: { organization_id: organization.id }
      end

      it 'redirects to root with error' do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('not authorized')
      end
    end

    context 'when user is admin' do
      before do
        allow(controller).to receive(:current_person).and_return(admin)
        get :index, params: { organization_id: organization.id }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end
    end
  end

  describe 'GET #show' do
    context 'when user has MAAP permissions' do
      before do
        get :show, params: { organization_id: organization.id, id: ability.id }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns the requested ability' do
        expect(assigns(:ability)).to eq(ability)
      end

      it 'renders show template' do
        expect(response).to render_template(:show)
      end
    end

    context 'when user lacks MAAP permissions' do
      before do
        allow(controller).to receive(:current_person).and_return(person)
        get :show, params: { organization_id: organization.id, id: ability.id }
      end

      it 'redirects to root with error' do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('not authorized')
      end
    end

    context 'when ability belongs to different organization' do
      let(:other_ability) { create(:ability, organization: other_organization) }

      before do
        get :show, params: { organization_id: organization.id, id: other_ability.id }
      end

      it 'returns not found' do
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'GET #new' do
    context 'when user has MAAP permissions' do
      before do
        get :new, params: { organization_id: organization.id }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns a new ability' do
        expect(assigns(:ability)).to be_a_new(Ability)
      end

      it 'renders new template' do
        expect(response).to render_template(:new)
      end
    end

    context 'when user lacks MAAP permissions' do
      before do
        allow(controller).to receive(:current_person).and_return(person)
        get :new, params: { organization_id: organization.id }
      end

      it 'redirects to root with error' do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('not authorized')
      end
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        organization_id: organization.id,
        ability: {
          name: 'Ruby Programming',
          description: 'Ability to write Ruby code effectively',
          version: '1.0.0'
        }
      }
    end

    context 'when user has MAAP permissions' do
      it 'creates a new ability' do
        expect {
          post :create, params: valid_params
        }.to change(Ability, :count).by(1)
      end

      it 'assigns the ability to the organization' do
        post :create, params: valid_params
        expect(Ability.last.organization).to eq(organization)
      end

      it 'assigns the current user as created_by and updated_by' do
        post :create, params: valid_params
        expect(Ability.last.created_by).to eq(maap_user)
        expect(Ability.last.updated_by).to eq(maap_user)
      end

      it 'redirects to the ability show page' do
        post :create, params: valid_params
        expect(response).to redirect_to(organization_ability_path(organization, Ability.last))
      end

      it 'sets success flash message' do
        post :create, params: valid_params
        expect(flash[:notice]).to include('Ability was successfully created')
      end
    end

    context 'when user lacks MAAP permissions' do
      before do
        allow(controller).to receive(:current_person).and_return(person)
      end

      it 'does not create a new ability' do
        expect {
          post :create, params: valid_params
        }.not_to change(Ability, :count)
      end

      it 'redirects to root with error' do
        post :create, params: valid_params
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('not authorized')
      end
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          organization_id: organization.id,
          ability: {
            name: '',
            description: '',
            version: ''
          }
        }
      end

      it 'does not create a new ability' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Ability, :count)
      end

      it 'renders new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET #edit' do
    context 'when user has MAAP permissions' do
      before do
        get :edit, params: { organization_id: organization.id, id: ability.id }
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns the requested ability' do
        expect(assigns(:ability)).to eq(ability)
      end

      it 'renders edit template' do
        expect(response).to render_template(:edit)
      end
    end

    context 'when user lacks MAAP permissions' do
      before do
        allow(controller).to receive(:current_person).and_return(person)
        get :edit, params: { organization_id: organization.id, id: ability.id }
      end

      it 'redirects to root with error' do
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('not authorized')
      end
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        organization_id: organization.id,
        id: ability.id,
        ability: {
          name: 'Updated Ruby Programming',
          description: 'Updated description'
        }
      }
    end

    context 'when user has MAAP permissions' do
      it 'updates the ability' do
        patch :update, params: update_params
        ability.reload
        expect(ability.name).to eq('Updated Ruby Programming')
      end

      it 'assigns the current user as updated_by' do
        patch :update, params: update_params
        ability.reload
        expect(ability.updated_by).to eq(maap_user)
      end

      it 'redirects to the ability show page' do
        patch :update, params: update_params
        expect(response).to redirect_to(organization_ability_path(organization, ability))
      end

      it 'sets success flash message' do
        patch :update, params: update_params
        expect(flash[:notice]).to include('Ability was successfully updated')
      end
    end

    context 'when user lacks MAAP permissions' do
      before do
        allow(controller).to receive(:current_person).and_return(person)
      end

      it 'does not update the ability' do
        original_name = ability.name
        patch :update, params: update_params
        ability.reload
        expect(ability.name).to eq(original_name)
      end

      it 'redirects to root with error' do
        patch :update, params: update_params
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('not authorized')
      end
    end

    context 'with invalid params' do
      let(:invalid_update_params) do
        {
          organization_id: organization.id,
          id: ability.id,
          ability: {
            name: '',
            description: ''
          }
        }
      end

      it 'does not update the ability' do
        original_name = ability.name
        patch :update, params: invalid_update_params
        ability.reload
        expect(ability.name).to eq(original_name)
      end

      it 'renders edit template' do
        patch :update, params: invalid_update_params
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    context 'when user has MAAP permissions' do
      it 'destroys the ability' do
        expect {
          delete :destroy, params: { organization_id: organization.id, id: ability.id }
        }.to change(Ability, :count).by(-1)
      end

      it 'redirects to abilities index' do
        delete :destroy, params: { organization_id: organization.id, id: ability.id }
        expect(response).to redirect_to(organization_abilities_path(organization))
      end

      it 'sets success flash message' do
        delete :destroy, params: { organization_id: organization.id, id: ability.id }
        expect(flash[:notice]).to include('Ability was successfully deleted')
      end
    end

    context 'when user lacks MAAP permissions' do
      before do
        allow(controller).to receive(:current_person).and_return(person)
      end

      it 'does not destroy the ability' do
        expect {
          delete :destroy, params: { organization_id: organization.id, id: ability.id }
        }.not_to change(Ability, :count)
      end

      it 'redirects to root with error' do
        delete :destroy, params: { organization_id: organization.id, id: ability.id }
        expect(response).to redirect_to(root_path)
        expect(flash[:alert]).to include('not authorized')
      end
    end
  end
end
