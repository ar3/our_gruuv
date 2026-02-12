require 'rails_helper'

RSpec.describe Organizations::SlackController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization, name: 'Test Company') }
  let(:team) { create(:team, company: company, name: 'Test Team') }
  let(:slack_config) { create(:slack_configuration, organization: company) }

  before do
    create(:teammate, person: person, organization: company, first_employed_at: 1.month.ago, last_terminated_at: nil, can_manage_employment: true)
    sign_in_as_teammate(person, company)
    slack_config
  end

  describe 'GET #show' do
    context 'when organization is a company' do
      it 'returns http success' do
        get :show, params: { organization_id: company.id }
        expect(response).to have_http_status(:success)
      end

      it 'loads summary data' do
        get :show, params: { organization_id: company.id }
        expect(assigns(:slack_config)).to eq(slack_config)
        expect(assigns(:total_teammates)).to be_a(Integer)
        expect(assigns(:linked_teammates)).to be_a(Integer)
      end

      it 'assigns teammates_with_manage_employment for the view' do
        get :show, params: { organization_id: company.id }
        expect(assigns(:teammates_with_manage_employment)).to be_an(Array)
      end
    end

    context 'when user is employed but does not have manage_employment' do
      before do
        teammate = person.teammates.find_by(organization: company)
        teammate.update!(can_manage_employment: false)
      end

      it 'returns success (view-only access)' do
        get :show, params: { organization_id: company.id }
        expect(response).to have_http_status(:success)
      end

      it 'assigns teammates_with_manage_employment' do
        manager = create(:person, first_name: 'Alice', last_name: 'Manager')
        create(:teammate, person: manager, organization: company, can_manage_employment: true, first_employed_at: 1.month.ago, last_terminated_at: nil)
        get :show, params: { organization_id: company.id }
        expect(assigns(:teammates_with_manage_employment)).to be_an(Array)
        expect(assigns(:teammates_with_manage_employment)).to include(manager.casual_name)
      end
    end

    context 'when user is not employed' do
      before do
        teammate = person.teammates.find_by(organization: company)
        teammate.update!(first_employed_at: nil, last_terminated_at: nil)
      end

      it 'redirects with authorization error' do
        get :show, params: { organization_id: company.id }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'GET #test_connection' do
    let(:test_result) do
      {
        'success' => true,
        'team' => 'Test Team',
        'team_id' => 'T123456',
        'steps' => {
          'auth' => { 'success' => true },
          'channels' => { 'success' => true, 'count' => 5 },
          'users' => { 'success' => true, 'count' => 10 },
          'test_message' => { 'success' => true }
        }
      }
    end

    before do
      allow(SlackService).to receive(:new).with(company).and_return(instance_double(SlackService, test_connection: test_result))
    end

    it 'returns JSON with success when user has manage_employment' do
      get :test_connection, params: { organization_id: company.id }
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json['success']).to be true
      expect(json['team']).to eq('Test Team')
      expect(json['team_id']).to eq('T123456')
      expect(json['steps']['auth']['success']).to be true
      expect(json['steps']['channels']['count']).to eq(5)
      expect(json['steps']['users']['count']).to eq(10)
      expect(json['steps']['test_message']['success']).to be true
    end

    context 'when user does not have manage_employment' do
      before do
        teammate = person.teammates.find_by(organization: company)
        teammate.update!(can_manage_employment: false)
      end

      it 'returns forbidden for JSON requests' do
        get :test_connection, params: { organization_id: company.id }, format: :json
        expect(response).to have_http_status(:forbidden)
        expect(response.parsed_body['error']).to be_present
      end

      it 'redirects with alert for HTML requests' do
        get :test_connection, params: { organization_id: company.id }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'PATCH #update_configuration' do
    it 'updates configuration and redirects when user has manage_employment' do
      patch :update_configuration, params: {
        organization_id: company.id,
        slack_configuration: {
          default_channel: '#new-channel',
          bot_username: 'NewBot',
          bot_emoji: ':rocket:'
        }
      }
      expect(response).to redirect_to(organization_slack_path(company))
      expect(flash[:notice]).to include('updated successfully')
      expect(slack_config.reload.default_channel).to eq('#new-channel')
    end

    context 'when user does not have manage_employment' do
      before do
        teammate = person.teammates.find_by(organization: company)
        teammate.update!(can_manage_employment: false)
      end

      it 'redirects with alert' do
        patch :update_configuration, params: {
          organization_id: company.id,
          slack_configuration: { default_channel: '#new-channel' }
        }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end
end

