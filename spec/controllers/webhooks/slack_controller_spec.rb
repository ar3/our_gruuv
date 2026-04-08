require 'rails_helper'

RSpec.describe Webhooks::SlackController, type: :controller do
  describe 'POST #create' do
    let(:organization) { create(:organization, :company, :with_slack_config) }
    let(:team_id) { 'T123456' }
    let(:trigger_id) { 'trigger.abc.123' }
    let(:interaction_payload) do
      {
        'type' => 'message_action',
        'callback_id' => 'create_observation_from_message',
        'trigger_id' => trigger_id,
        'team' => { 'id' => team_id },
        'channel' => { 'id' => 'CCHANNEL1' },
        'user' => { 'id' => 'UOBSERVER' },
        'message' => {
          'ts' => '1234567890.123456',
          'user' => 'UAUTHOR',
          'text' => 'Hello <@UMENTIONED>',
          'thread_ts' => '1234567890.000001'
        }
      }
    end

    before do
      organization.slack_configuration.update!(workspace_id: team_id)
      allow_any_instance_of(Webhooks::SlackController).to receive(:verify_slack_signature!)
    end

    it 'opens modal with private_metadata including payload_message_text from the message' do
      slack_service = instance_double(SlackService)
      allow(SlackService).to receive(:new).with(organization).and_return(slack_service)

      expect(slack_service).to receive(:open_create_observation_modal) do |_tid, metadata_json|
        meta = JSON.parse(metadata_json)
        expect(meta['payload_message_text']).to eq('Hello <@UMENTIONED>')
        expect(meta['message_user_id']).to eq('UAUTHOR')
        expect(meta['triggering_user_id']).to eq('UOBSERVER')
        expect(meta['message_thread_ts']).to eq('1234567890.000001')
        { success: true }
      end

      post :create, params: { payload: interaction_payload.to_json }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'POST #event' do
    let(:signing_secret) { 'test-signing-secret' }
    let(:timestamp) { Time.now.to_i.to_s }
    let(:raw_body) { params.to_json }
    let(:signature) { 'v0=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), signing_secret, "v0:#{timestamp}:#{raw_body}") }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('SLACK_SIGNING_SECRET').and_return(signing_secret)
      request.headers['X-Slack-Request-Timestamp'] = timestamp
      request.headers['X-Slack-Signature'] = signature
    end

    let(:team_id) { 'T123456' }
    let(:organization) { create(:organization, :company, :with_slack_config) }
    let(:slack_config) { organization.slack_configuration }
    let(:event_type) { 'message' }
    let(:challenge) { 'test-challenge-token' }
    let(:params) do
      {
        token: 'test-token',
        challenge: challenge,
        team_id: team_id,
        event: {
          type: event_type,
          text: 'Test message'
        }
      }
    end
    let(:mock_s3_client) { instance_double(S3::Client) }

    before do
      allow(S3::Client).to receive(:new).and_return(mock_s3_client)
      allow(mock_s3_client).to receive(:save_json_to_s3).and_return(true)
      slack_config.update(workspace_id: team_id)
    end

    context 'when challenge verification is requested' do
      let(:params) { { type: 'url_verification', challenge: challenge } }

      it 'returns the challenge token' do
        post :event, params: params, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'challenge' => challenge })
      end

      it 'does not save to S3' do
        post :event, params: params, as: :json

        expect(mock_s3_client).not_to have_received(:save_json_to_s3)
      end
    end

    context 'when organization exists and has Slack configured' do
      it 'saves event to S3' do
        post :event, params: params, as: :json

        expect(mock_s3_client).to have_received(:save_json_to_s3) do |args|
          expect(args[:full_file_path_and_name]).to match(/slack-events\/test\/#{organization.name.parameterize}\/#{event_type}\/\d{4}\/\d{2}\/\d{2}\/t_?\d+_\d+_\d+_\d+\.json/)
          # Check that hash_object contains the expected params
          expect(args[:hash_object]['team_id']).to eq(team_id)
          expect(args[:hash_object]['event']['type']).to eq(event_type)
        end
      end

      it 'returns challenge response' do
        post :event, params: params, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'challenge' => challenge })
      end
    end

    context 'when organization does not exist' do
      let(:team_id) { 'T999999' }

      before do
        # Ensure no organization exists for this team_id
        Organization.joins(:slack_configuration).where(slack_configurations: { workspace_id: team_id }).destroy_all
      end

      it 'does not save to S3' do
        post :event, params: params, as: :json

        expect(mock_s3_client).not_to have_received(:save_json_to_s3)
      end

      it 'still returns challenge response' do
        post :event, params: params, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'challenge' => challenge })
      end
    end

    context 'when organization exists but Slack is not configured' do
      before do
        organization.slack_configuration.destroy
      end

      it 'does not save to S3' do
        post :event, params: params, as: :json

        expect(mock_s3_client).not_to have_received(:save_json_to_s3)
      end

      it 'still returns challenge response' do
        post :event, params: params, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'challenge' => challenge })
      end
    end

    context 'when event type is missing' do
      let(:params) do
        {
          token: 'test-token',
          challenge: challenge,
          team_id: team_id
        }
      end

      it 'uses unknown-event as default' do
        post :event, params: params, as: :json

        expect(mock_s3_client).to have_received(:save_json_to_s3) do |args|
          expect(args[:full_file_path_and_name]).to include('unknown-event')
        end
      end
    end

    context 'when S3 save fails' do
      before do
        allow(mock_s3_client).to receive(:save_json_to_s3).and_raise(StandardError.new('S3 Error'))
      end

      it 'still returns challenge response' do
        post :event, params: params, as: :json

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq({ 'challenge' => challenge })
      end

      it 'logs the error' do
        # The error is caught by ApplicationController's error handler
        expect(Rails.logger).to receive(:error).at_least(:once)
        post :event, params: params, as: :json
      end
    end
  end
end

