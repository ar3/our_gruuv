require 'rails_helper'

RSpec.describe Organizations::Slack::ChannelsController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization, :company, name: 'Test Company') }
  let(:department) { create(:organization, :department, name: 'Test Department', parent: company) }
  let(:team) { create(:organization, :team, name: 'Test Team', parent: department) }
  let(:slack_config) { create(:slack_configuration, organization: company) }
  let(:mock_slack_service) { instance_double(SlackService) }
  let(:mock_channels_service) { instance_double(SlackChannelsService) }
  let(:mock_groups_service) { instance_double(SlackGroupsService) }

  before do
    teammate = create(:teammate, person: person, organization: company)
    sign_in_as_teammate(person, company)
    slack_config
    allow(SlackService).to receive(:new).with(kind_of(Organization)).and_return(mock_slack_service)
    allow(SlackChannelsService).to receive(:new).with(kind_of(Organization)).and_return(mock_channels_service)
    allow(SlackGroupsService).to receive(:new).with(kind_of(Organization)).and_return(mock_groups_service)
  end

  describe 'GET #index' do
    it 'returns http success' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'loads organization hierarchy' do
      department
      team
      get :index, params: { organization_id: company.id }
      org_ids = assigns(:organizations).map(&:id)
      expect(org_ids).to include(company.id, department.id, team.id)
    end

    it 'loads channels and groups' do
      channel = create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C123456')
      group = create(:third_party_object, :slack_group, organization: company, third_party_id: 'S123456')
      
      get :index, params: { organization_id: company.id }
      expect(assigns(:slack_channels)).to include(channel)
      expect(assigns(:slack_groups)).to include(group)
    end
  end

  describe 'POST #refresh_channels' do
    before do
      allow(mock_channels_service).to receive(:refresh_channels).and_return(true)
    end

    it 'refreshes channels and redirects' do
      post :refresh_channels, params: { organization_id: company.id }
      expect(response).to redirect_to(channels_organization_slack_path(company))
      expect(flash[:notice]).to include('refreshed successfully')
    end
  end

  describe 'POST #refresh_groups' do
    before do
      allow(mock_groups_service).to receive(:refresh_groups).and_return(true)
    end

    it 'refreshes groups and redirects' do
      post :refresh_groups, params: { organization_id: company.id }
      expect(response).to redirect_to(channels_organization_slack_path(company))
      expect(flash[:notice]).to include('refreshed successfully')
    end
  end

  describe 'PATCH #update_channel' do
    let(:channel) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C123456') }

    it 'updates channel association for company' do
      patch :update_channel, params: {
        organization_id: company.id,
        channel_id: channel.third_party_id
      }
      expect(response).to redirect_to(channels_organization_slack_path(company))
      company_record = Company.find(company.id)
      expect(company_record.huddle_review_notification_channel_id).to eq(channel.third_party_id)
    end
  end

  describe 'PATCH #update_group' do
    let(:group) { create(:third_party_object, :slack_group, organization: company, third_party_id: 'S789012') }

    it 'updates group association' do
      patch :update_group, params: {
        organization_id: company.id,
        group_id: group.third_party_id
      }
      expect(response).to redirect_to(channels_organization_slack_path(company))
      expect(company.reload.slack_group_id).to eq(group.third_party_id)
    end
  end
end

