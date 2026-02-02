require 'rails_helper'

RSpec.describe Organizations::Slack::ChannelsController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { create(:organization, name: 'Test Company') }
  let(:department1) { create(:department, company: company, name: 'Department 1') }
  let(:department2) { create(:department, company: company, name: 'Department 2') }
  let(:team1) { create(:team, company: company, name: 'Team 1') }
  let(:team2) { create(:team, company: company, name: 'Team 2') }
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
      department1
      department2
      team1
      team2
      get :index, params: { organization_id: company.id }
      # Note: Departments and Teams are no longer Organizations (STI removed)
      # The organizations list now only contains the company itself
      org_ids = assigns(:organizations).map(&:id)
      expect(org_ids).to include(company.id)
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

  describe 'GET #edit and PATCH #update' do
    let(:channel1) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C111111') }
    let(:channel2) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C222222') }
    let(:channel3) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C333333') }
    let(:group1) { create(:third_party_object, :slack_group, organization: company, third_party_id: 'S111111') }
    let(:group2) { create(:third_party_object, :slack_group, organization: company, third_party_id: 'S222222') }

    it 'renders edit for a valid organization' do
      get :edit, params: { organization_id: company.id, target_organization_id: company.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:target_organization).id).to eq(company.id)
    end

    it 'updates kudos and group for company' do
      patch :update, params: {
        organization_id: company.id,
        target_organization_id: company.id,
        organization: {
          kudos_channel_id: channel2.third_party_id,
          slack_group_id: group1.third_party_id
        }
      }
      expect(response).to redirect_to(channels_organization_slack_path(company))
      expect(flash[:notice]).to include('Channel settings updated successfully.')

      expect(company.reload.kudos_channel_id).to eq(channel2.third_party_id)
      expect(company.reload.slack_group_id).to eq(group1.third_party_id)
    end

    # Note: Department-specific update tests removed - Departments are no longer Organizations (STI removed).
    # Slack channel settings apply to Organizations (companies) only.

    it 'clears kudos and group when values are blank' do
      company.kudos_channel_id = channel1.third_party_id
      company.slack_group_id = group1.third_party_id
      company.save!

      patch :update, params: {
        organization_id: company.id,
        target_organization_id: company.id,
        organization: {
          kudos_channel_id: '',
          slack_group_id: ''
        }
      }
      expect(response).to redirect_to(channels_organization_slack_path(company))

      expect(company.reload.kudos_channel_id).to be_nil
      expect(company.reload.slack_group_id).to be_nil
    end
  end

  describe 'GET #edit_company and PATCH #update_company' do
    let(:channel1) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C111111') }
    let(:channel2) { create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C222222') }

    it 'renders edit_company for a company' do
      get :edit_company, params: { organization_id: company.id, target_organization_id: company.id }
      expect(response).to have_http_status(:success)
      expect(assigns(:target_organization).id).to eq(company.id)
      expect(assigns(:target_organization)).to be_a(Organization)
    end

    # Note: This test was removed because STI types have been removed from Organization.
    # Departments are no longer Organizations, so this redirect case no longer applies.

    it 'updates huddle review channel for company' do
      patch :update_company, params: {
        organization_id: company.id,
        target_organization_id: company.id,
        organization: {
          huddle_review_channel_id: channel1.third_party_id
        }
      }
      expect(response).to redirect_to(channels_organization_slack_path(company))
      expect(flash[:notice]).to include('Company-only channels updated successfully.')

      company.reload
      expect(company.huddle_review_notification_channel_id).to eq(channel1.third_party_id)
    end

    it 'clears huddle review channel when value is blank' do
      company.huddle_review_notification_channel_id = channel1.third_party_id
      company.save!

      patch :update_company, params: {
        organization_id: company.id,
        target_organization_id: company.id,
        organization: {
          huddle_review_channel_id: ''
        }
      }
      expect(response).to redirect_to(channels_organization_slack_path(company))

      company.reload
      expect(company.huddle_review_notification_channel_id).to be_nil
    end
  end
end


