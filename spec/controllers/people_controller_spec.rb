require 'rails_helper'

RSpec.describe PeopleController, type: :controller do
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }

  before do
    # Create a teammate for the person - use default organization
    teammate = create(:teammate, person: person, organization: create(:organization, :company))
    sign_in_as_teammate(person, teammate.organization)
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
      before { session[:current_company_teammate_id] = nil }

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
      before { session[:current_company_teammate_id] = nil }

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

    context 'with blank phone number' do
      let(:blank_phone_params) do
        {
          person: {
            unique_textable_phone_number: ''
          }
        }
      end

      it 'successfully updates with blank phone number' do
        patch :update, params: blank_phone_params
        person.reload
        expect(person.unique_textable_phone_number).to be_nil
      end
    end

    context 'with duplicate phone number' do
      let!(:existing_person) { create(:person, unique_textable_phone_number: '+1234567890') }
      
      let(:duplicate_phone_params) do
        {
          person: {
            unique_textable_phone_number: '+1234567890'
          }
        }
      end

      it 'handles unique constraint violation gracefully' do
        patch :update, params: duplicate_phone_params
        expect(response).to render_template(:edit)
        expect(assigns(:person).errors[:unique_textable_phone_number]).to include('has already been taken')
      end
    end

    context 'with database constraint violation' do
      before do
        allow_any_instance_of(Person).to receive(:update).and_raise(
          ActiveRecord::StatementInvalid.new('PG::UniqueViolation')
        )
      end

      it 'handles database constraint violation gracefully' do
        patch :update, params: { person: { first_name: 'Jane' } }
        expect(response).to render_template(:edit)
        expect(assigns(:person).errors[:base]).to include('Unable to update profile due to a database constraint. Please try again.')
      end
    end

    context 'with unexpected error' do
      before do
        allow_any_instance_of(Person).to receive(:update).and_raise(StandardError.new('Unexpected error'))
      end

      it 'handles unexpected errors gracefully' do
        patch :update, params: { person: { first_name: 'Jane' } }
        expect(response).to render_template(:edit)
        expect(assigns(:person).errors[:base]).to include('An unexpected error occurred while updating your profile. Please try again.')
      end
    end

    context 'when not logged in' do
      before { session[:current_company_teammate_id] = nil }

      it 'redirects to root path' do
        patch :update, params: { person: { first_name: 'Jane' } }
        expect(response).to redirect_to(root_path)
      end
    end
  end
end 