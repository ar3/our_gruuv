# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::Slack::Channels (edit-company page)', type: :request do
  let(:organization) { create(:organization, name: 'Careerplug') }
  let(:person) { create(:person) }
  # Employed teammate with manage_employment so view_slack_settings? and manage_employment? pass
  let(:teammate) do
    create(:teammate, person: person, organization: organization,
           first_employed_at: 1.year.ago, last_terminated_at: nil, can_manage_employment: true)
  end
  let(:slack_config) { create(:slack_configuration, organization: organization) }

  before do
    teammate
    slack_config
    sign_in_as_teammate_for_request(person, organization)
    allow(SlackService).to receive(:new).with(kind_of(Organization)).and_return(instance_double(SlackService))
  end

  describe 'GET /organizations/:organization_id/slack/channels/:target_organization_id/edit-company' do
    let(:path) do
      edit_company_channel_organization_slack_path(
        organization,
        target_organization_id: organization.id
      )
    end

    it 'returns http success' do
      get path
      expect(response).to have_http_status(:success)
    end

    it 'renders the edit company channel page' do
      get path
      expect(response.body).to include('Edit Company-Only Channel Settings')
      expect(response.body).to include('Huddle Review Channel')
      expect(response.body).to include('Comment Channel')
      expect(response.body).to include('Kudos Channel')
      expect(response.body).to include(organization.name)
      expect(response.body).to include('Save Settings')
      expect(response.body).to include('Cancel')
    end

    it 'includes form with correct action' do
      get path
      expect(response.body).to include(company_channel_organization_slack_path(organization, target_organization_id: organization.id))
    end

    it 'includes back link to channels index' do
      get path
      expect(response.body).to include(channels_organization_slack_path(organization))
    end

    context 'when not signed in' do
      before { sign_out_teammate_for_request }

      it 'redirects to root path' do
        get path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end

    context 'when target_organization_id is not allowed' do
      let(:other_organization) { create(:organization, name: 'Other Company') }

      it 'redirects with alert when target is another company' do
        get edit_company_channel_organization_slack_path(
          organization,
          target_organization_id: other_organization.id
        )
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(channels_organization_slack_path(organization))
        follow_redirect!
        expect(flash[:alert]).to eq('Organization not found.')
      end
    end

    context 'when target_organization_id is a department' do
      let(:department) { create(:department, company: organization, name: 'Engineering') }

      it 'redirects with alert (company-only settings require organization id)' do
        get edit_company_channel_organization_slack_path(
          organization,
          target_organization_id: department.id
        )
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(channels_organization_slack_path(organization))
        follow_redirect!
        expect(flash[:alert]).to eq('Organization not found.')
      end
    end
  end

  describe 'PATCH /organizations/:organization_id/slack/channels/:target_organization_id/update-company' do
    let(:path) do
      company_channel_organization_slack_path(
        organization,
        target_organization_id: organization.id
      )
    end

    let(:slack_channel) do
      create(:third_party_object, :slack_channel, organization: organization, third_party_id: 'C123456')
    end

    before { slack_channel }

    it 'updates huddle review channel and redirects' do
      patch path, params: {
        organization: {
          huddle_review_channel_id: slack_channel.third_party_id,
          maap_object_comment_channel_id: ''
        }
      }
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(channels_organization_slack_path(organization))
      follow_redirect!
      expect(flash[:notice]).to include('Company-only channels updated successfully')
      expect(organization.reload.huddle_review_notification_channel_id).to eq(slack_channel.third_party_id)
    end

    it 'updates comment channel and redirects' do
      patch path, params: {
        organization: {
          huddle_review_channel_id: '',
          maap_object_comment_channel_id: slack_channel.third_party_id
        }
      }
      expect(response).to have_http_status(:redirect)
      expect(organization.reload.maap_object_comment_channel_id).to eq(slack_channel.third_party_id)
    end

    it 'updates kudos channel and redirects' do
      patch path, params: {
        organization: {
          kudos_channel_id: slack_channel.third_party_id
        }
      }
      expect(response).to have_http_status(:redirect)
      expect(organization.reload.kudos_channel_id).to eq(slack_channel.third_party_id)
    end

    context 'when target_organization_id is a department' do
      let(:department) { create(:department, company: organization, name: 'Engineering') }

      it 'redirects with alert and does not update' do
        patch company_channel_organization_slack_path(
          organization,
          target_organization_id: department.id
        ), params: { organization: { huddle_review_channel_id: slack_channel.third_party_id } }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(channels_organization_slack_path(organization))
        follow_redirect!
        expect(flash[:alert]).to eq('Organization not found.')
        expect(organization.reload.huddle_review_notification_channel_id).not_to eq(slack_channel.third_party_id)
      end
    end
  end
end
