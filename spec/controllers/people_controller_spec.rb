require 'rails_helper'

RSpec.describe PeopleController, type: :controller do
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }

  before do
    session[:current_person_id] = person.id
  end

  describe 'GET #show' do
    it 'returns http success' do
      get :show
      expect(response).to have_http_status(:success)
    end

    it 'assigns @person' do
      get :show
      expect(assigns(:person)).to eq(person)
    end

    context 'when not logged in' do
      before { session[:current_person_id] = nil }

      it 'redirects to root path' do
        get :show
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'GET #edit' do
    it 'returns http success' do
      get :edit
      expect(response).to have_http_status(:success)
    end

    it 'assigns @person' do
      get :edit
      expect(assigns(:person)).to eq(person)
    end

    context 'when not logged in' do
      before { session[:current_person_id] = nil }

      it 'redirects to root path' do
        get :edit
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          person: {
            first_name: 'Jane',
            last_name: 'Smith',
            timezone: 'Pacific Time (US & Canada)'
          }
        }
      end

      it 'updates the person' do
        patch :update, params: valid_params
        person.reload
        expect(person.first_name).to eq('Jane')
        expect(person.last_name).to eq('Smith')
        expect(person.timezone).to eq('Pacific Time (US & Canada)')
      end

      it 'redirects to profile path with notice' do
        patch :update, params: valid_params
        expect(response).to redirect_to(profile_path)
        expect(flash[:notice]).to eq('Profile updated successfully!')
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          person: {
            email: 'invalid-email'
          }
        }
      end

      it 'does not update the person' do
        original_email = person.email
        patch :update, params: invalid_params
        person.reload
        expect(person.email).to eq(original_email)
      end

      it 'renders edit template' do
        patch :update, params: invalid_params
        expect(response).to render_template(:edit)
      end
    end

    context 'when not logged in' do
      before { session[:current_person_id] = nil }

      it 'redirects to root path' do
        patch :update, params: { person: { first_name: 'Jane' } }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end 