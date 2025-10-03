require 'rails_helper'

RSpec.describe Organizations::PersonAccessesController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, type: 'Company') }
  let(:teammate) { create(:teammate, person: person, organization: organization, can_manage_employment: true) }

  before do
    session[:current_person_id] = person.id
  end

  describe 'GET #new' do
    xit 'assigns a new teammate' do
      get :new, params: { organization_id: organization.id }
      expect(assigns(:teammate)).to be_a_new(Teammate)
      expect(assigns(:teammate).person).to eq(person)
      expect(assigns(:teammate).organization).to eq(organization)
    end

    xit 'authorizes the action' do
      expect(controller).to receive(:authorize).with(an_instance_of(Teammate))
      get :new, params: { organization_id: organization.id }
    end
  end

  describe 'POST #create' do
    let(:valid_params) do
      {
        organization_id: organization.id,
        teammate: {
          can_manage_employment: true,
          can_manage_maap: false
        }
      }
    end

    context 'with valid parameters' do
      xit 'creates a new teammate' do
        expect {
          post :create, params: valid_params
        }.to change(Teammate, :count).by(1)
      end

      xit 'sets the person to current_person' do
        post :create, params: valid_params
        expect(Teammate.last.person).to eq(person)
      end

      xit 'sets the organization to the current organization' do
        post :create, params: valid_params
        expect(Teammate.last.organization).to eq(organization)
      end

      xit 'redirects to profile with success notice' do
        post :create, params: valid_params
        expect(response).to redirect_to(profile_path)
        expect(flash[:notice]).to eq('Organization permission was successfully created.')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          organization_id: organization.id,
          teammate: {
            can_manage_employment: nil,
            can_manage_maap: nil
          }
        }
      end

      xit 'does not create a teammate' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Teammate, :count)
      end

      xit 'renders new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end

    xit 'authorizes the action' do
      expect(controller).to receive(:authorize).with(an_instance_of(Teammate))
      post :create, params: valid_params
    end
  end

  describe 'GET #edit' do
    xit 'assigns the requested teammate' do
      get :edit, params: { organization_id: organization.id, id: teammate.id }
      expect(assigns(:teammate)).to eq(teammate)
    end

    xit 'authorizes the action' do
      expect(controller).to receive(:authorize).with(teammate)
      get :edit, params: { organization_id: organization.id, id: teammate.id }
    end
  end

  describe 'PATCH #update' do
    let(:update_params) do
      {
        organization_id: organization.id,
        id: teammate.id,
        teammate: {
          can_manage_employment: false,
          can_manage_maap: true
        }
      }
    end

    context 'with valid parameters' do
      xit 'updates the teammate' do
        patch :update, params: update_params
        teammate.reload
        expect(teammate.can_manage_employment).to be false
        expect(teammate.can_manage_maap).to be true
      end

      xit 'redirects to profile with success notice' do
        patch :update, params: update_params
        expect(response).to redirect_to(profile_path)
        expect(flash[:notice]).to eq('Organization permission was successfully updated.')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_update_params) do
        {
          organization_id: organization.id,
          id: teammate.id,
          teammate: {
            can_manage_employment: nil,
            can_manage_maap: nil
          }
        }
      end

      xit 'does not update the teammate' do
        original_employment = teammate.can_manage_employment
        patch :update, params: invalid_update_params
        teammate.reload
        expect(teammate.can_manage_employment).to eq(original_employment)
      end

      xit 'renders edit template' do
        patch :update, params: invalid_update_params
        expect(response).to render_template(:edit)
      end
    end

    xit 'authorizes the action' do
      expect(controller).to receive(:authorize).with(teammate)
      patch :update, params: update_params
    end
  end

  describe 'DELETE #destroy' do
    xit 'destroys the requested teammate' do
      teammate # Create the record
      expect {
        delete :destroy, params: { organization_id: organization.id, id: teammate.id }
      }.to change(Teammate, :count).by(-1)
    end

    xit 'redirects to profile with success notice' do
      delete :destroy, params: { organization_id: organization.id, id: teammate.id }
      expect(response).to redirect_to(profile_path)
      expect(flash[:notice]).to eq('Organization permission was successfully removed.')
    end

    xit 'authorizes the action' do
      expect(controller).to receive(:authorize).with(teammate)
      delete :destroy, params: { organization_id: organization.id, id: teammate.id }
    end
  end
end
