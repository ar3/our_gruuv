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
      let(:company) { create(:organization) }
      let(:person) { create(:person) }

      before do
        sign_in_as_teammate_for_request(person, company)
      end

      it 'redirects to the teammate preferred start page' do
        get login_path
        teammate = person.company_teammates.find_by!(organization: company)
        # Default start page preference is About Me (see ApplicationHelper#start_page_preference).
        expect(response).to redirect_to(about_me_organization_company_teammate_path(company, teammate))
      end
    end
  end
end
