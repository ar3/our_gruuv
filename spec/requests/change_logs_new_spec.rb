require 'rails_helper'

RSpec.describe 'ChangeLogs#new', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:admin_person) { create(:person, :admin) }
  let(:regular_person) { create(:person) }

  describe 'GET /change_logs/new' do
    context 'when user is an admin' do
      before do
        sign_in_as_teammate_for_request(admin_person, organization)
      end

      it 'allows access to the new change log page' do
        get new_change_log_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the new change log form' do
        get new_change_log_path
        expect(response.body).to include('New Change Log')
        expect(response.body).to include('Create Change Log')
        expect(response.body).to include('Launch Date')
        expect(response.body).to include('Change Type')
        expect(response.body).to include('Description')
        expect(response.body).to include('Image URL')
      end

      it 'initializes a new change log instance' do
        get new_change_log_path
        expect(assigns(:change_log)).to be_a_new(ChangeLog)
      end

      it 'includes a back link to change logs index' do
        get new_change_log_path
        expect(response.body).to include('Back to Change Logs')
        expect(response.body).to include(change_logs_path)
      end
    end

    context 'when user is not an admin' do
      before do
        sign_in_as_teammate_for_request(regular_person, organization)
      end

      it 'denies access and redirects' do
        get new_change_log_path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end

      it 'sets flash alert message' do
        get new_change_log_path
        expect(flash[:alert]).to be_present
      end
    end

    context 'when user is unauthenticated' do
      it 'denies access and redirects' do
        get new_change_log_path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end
  end
end

