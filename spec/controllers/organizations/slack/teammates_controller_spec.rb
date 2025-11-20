require 'rails_helper'

RSpec.describe Organizations::Slack::TeammatesController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company, name: 'Test Company') }
  let(:slack_config) { create(:slack_configuration, organization: company) }
  let(:mock_slack_service) { instance_double(SlackService) }

  before do
    teammate = create(:teammate, person: person, organization: company)
    sign_in_as_teammate(person, company)
    slack_config
    allow(SlackService).to receive(:new).with(kind_of(Organization)).and_return(mock_slack_service)
  end

  describe 'GET #index' do
    let(:slack_users) do
      [
        {
          'id' => 'U123456',
          'name' => 'testuser',
          'profile' => {
            'email' => 'test@example.com',
            'real_name' => 'Test User',
            'image_512' => 'https://slack.com/avatar.jpg'
          }
        }
      ]
    end

    before do
      allow(mock_slack_service).to receive(:list_users).and_return(slack_users)
    end

    context 'when organization is a company' do
      it 'returns http success' do
        get :index, params: { organization_id: company.id }
        expect(response).to have_http_status(:success)
      end

      it 'loads teammates and Slack users' do
        get :index, params: { organization_id: company.id }
        expect(assigns(:teammates)).to be_present
        expect(assigns(:slack_users)).to eq(slack_users)
      end
    end

    context 'when organization is not a company' do
      let(:team) { create(:organization, :team, parent: company) }

      before do
        teammate = create(:teammate, person: person, organization: team)
        sign_in_as_teammate(person, team)
      end

      it 'redirects to organization path' do
        get :index, params: { organization_id: team.id }
        expect(response).to redirect_to(organization_path(team))
      end
    end
  end

  describe 'PATCH #update' do
    let(:teammate) { create(:teammate, person: create(:person, email: 'new@example.com'), organization: company) }
    let(:slack_users) do
      [
        {
          'id' => 'U789012',
          'name' => 'newuser',
          'profile' => {
            'email' => 'new@example.com',
            'real_name' => 'New User',
            'image_512' => 'https://slack.com/new-avatar.jpg'
          }
        }
      ]
    end

    before do
      allow(mock_slack_service).to receive(:list_users).and_return(slack_users)
    end

    it 'creates teammate identity and redirects' do
      patch :update, params: {
        organization_id: company.id,
        teammate_id: teammate.id,
        slack_user_id: 'U789012'
      }
      expect(response).to redirect_to(teammates_organization_slack_path(company))
      expect(teammate.reload.slack_identity).to be_present
      expect(teammate.slack_identity.uid).to eq('U789012')
    end

    it 'removes association when slack_user_id is empty' do
      create(:teammate_identity, :slack, teammate: teammate, uid: 'U789012')
      
      patch :update, params: {
        organization_id: company.id,
        teammate_id: teammate.id,
        slack_user_id: ''
      }
      expect(response).to redirect_to(teammates_organization_slack_path(company))
      expect(teammate.reload.slack_identity).to be_nil
    end
  end
end

