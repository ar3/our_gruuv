require 'rails_helper'

RSpec.describe 'Login Page', type: :request do
  describe 'GET /login' do
    context 'when user is not logged in' do
      it 'shows the login page' do
        get login_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include('Sign In')
        expect(response.body).to include('I have an account')
        expect(response.body).to include('I&#39;m new here')
      end

      it 'renders without HAML syntax errors' do
        expect { get login_path }.not_to raise_error
        expect(response).to have_http_status(:success)
      end
    end

    context 'when user is already logged in' do
      let(:person) { create(:person) }

      it 'redirects to dashboard' do
        allow_any_instance_of(ApplicationController).to receive(:current_person).and_return(person)
        get login_path
        expect(response).to redirect_to(dashboard_path)
      end
    end
  end
end
