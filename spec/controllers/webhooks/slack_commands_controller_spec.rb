require 'rails_helper'

RSpec.describe Webhooks::SlackCommandsController, type: :controller do
  let(:signing_secret) { 'test-signing-secret' }
  let(:timestamp) { Time.now.to_i.to_s }
  
  # Helper to build form-encoded body and signature
  def build_request_params(text_value)
    params_hash = {
      token: 'test-token',
      team_id: team_id,
      team_domain: 'test',
      channel_id: channel_id,
      channel_name: 'general',
      user_id: user_id,
      user_name: 'testuser',
      command: '/og',
      text: text_value,
      response_url: 'https://hooks.slack.com/commands/123/456',
      trigger_id: '123.456.789'
    }
    raw_body = params_hash.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
    signature = 'v0=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), signing_secret, "v0:#{timestamp}:#{raw_body}")
    [params_hash, raw_body, signature]
  end
  
  # Helper to set up request with proper raw_post for signature verification
  def setup_request_with_signature(params_hash, raw_body, sig)
    request.headers['X-Slack-Request-Timestamp'] = timestamp
    request.headers['X-Slack-Signature'] = sig
    # Set raw_post by stubbing the method
    allow_any_instance_of(ActionDispatch::Request).to receive(:raw_post).and_return(raw_body)
  end
  
  let(:team_id) { 'T123456' }
  let(:channel_id) { 'C123456' }
  let(:user_id) { 'U123456' }
  let(:text) { 'feedback Great work!' }
  let(:organization) { create(:organization, :company, :with_slack_config) }
  let(:slack_config) { organization.slack_configuration }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('SLACK_SIGNING_SECRET').and_return(signing_secret)
    slack_config.update(workspace_id: team_id)
    create(:teammate_identity, teammate: teammate, provider: 'slack', uid: user_id)
  end

  describe 'POST #create' do
    context 'with valid signature' do
      context 'when command is feedback' do
        let(:text) { 'feedback Great work @user1!' }
        
        before do
          allow(Slack::ProcessFeedbackCommandService).to receive(:call).and_return(Result.ok(create(:observation, observer: person, company: organization)))
        end

        it 'processes the feedback command' do
          params_hash, raw_body, sig = build_request_params(text)
          setup_request_with_signature(params_hash, raw_body, sig)
          post :create, params: params_hash
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['text']).to include('Observation created successfully')
        end

        it 'creates an IncomingWebhook record' do
          params_hash, raw_body, sig = build_request_params(text)
          setup_request_with_signature(params_hash, raw_body, sig)
          expect {
            post :create, params: params_hash
          }.to change(IncomingWebhook, :count).by(1)
        end
      end

      context 'when command has alias (observe)' do
        let(:text) { 'observe Great work!' }
        
        before do
          allow(Slack::ProcessFeedbackCommandService).to receive(:call).and_return(Result.ok(create(:observation, observer: person, company: organization)))
        end

        it 'processes as feedback command' do
          params_hash, raw_body, sig = build_request_params(text)
          setup_request_with_signature(params_hash, raw_body, sig)
          post :create, params: params_hash
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when command has alias (kudos)' do
        let(:text) { 'kudos Great work!' }
        
        before do
          allow(Slack::ProcessFeedbackCommandService).to receive(:call).and_return(Result.ok(create(:observation, observer: person, company: organization)))
        end

        it 'processes as feedback command' do
          params_hash, raw_body, sig = build_request_params(text)
          setup_request_with_signature(params_hash, raw_body, sig)
          post :create, params: params_hash
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when command has alias (note)' do
        let(:text) { 'note Remember to follow up' }
        
        before do
          allow(Slack::ProcessFeedbackCommandService).to receive(:call).and_return(Result.ok(create(:observation, observer: person, company: organization)))
        end

        it 'processes as feedback command' do
          params_hash, raw_body, sig = build_request_params(text)
          setup_request_with_signature(params_hash, raw_body, sig)
          post :create, params: params_hash
          expect(response).to have_http_status(:ok)
        end
      end

      context 'when command is huddle' do
        let(:text) { 'huddle' }
        let(:channel_id) { 'C123456' }
        let(:channel_name) { 'general' }
        let!(:slack_channel) do
          create(:third_party_object, :slack_channel,
                 organization: organization,
                 third_party_id: channel_id,
                 display_name: channel_name)
        end
        let!(:playbook) do
          create(:team,
                 organization: organization,
                 slack_channel: "##{channel_name}")
        end

        before do
          allow(Slack::ProcessHuddleCommandService).to receive(:call).and_return(
            Result.ok("Huddle started successfully! View it here: http://example.com/huddles/1")
          )
        end

        it 'processes huddle command' do
          params_hash, raw_body, sig = build_request_params(text)
          setup_request_with_signature(params_hash, raw_body, sig)
          post :create, params: params_hash
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['text']).to include('Huddle started successfully')
        end
      end

      context 'when command is goal-check' do
        let(:text) { 'goal-check' }
        let(:trigger_id) { '123.456.789' }

        before do
          params_hash, raw_body, sig = build_request_params(text)
          params_hash[:trigger_id] = trigger_id
          raw_body = params_hash.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')
          signature = 'v0=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), signing_secret, "v0:#{timestamp}:#{raw_body}")
          setup_request_with_signature(params_hash, raw_body, signature)
        end

        context 'when user has goals' do
          let!(:goal) do
            create(:goal, 
                   owner: teammate.person, 
                   creator: teammate, 
                   company: organization)
          end

          before do
            allow(Slack::ProcessGoalCheckCommandService).to receive(:call).and_return(
              Result.ok("Opening goal check-in form...")
            )
          end

          it 'opens goal check-in modal' do
            post :create, params: build_request_params(text).first.merge(trigger_id: trigger_id)
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['text']).to include('Opening goal check-in form')
          end
        end

        context 'when user has no goals' do
          before do
            allow(Slack::ProcessGoalCheckCommandService).to receive(:call).and_return(
              Result.err("You don't have any goals available for check-in. Create a goal first in OurGruuv.")
            )
          end

          it 'returns error message' do
            post :create, params: build_request_params(text).first.merge(trigger_id: trigger_id)
            expect(response).to have_http_status(:ok)
            expect(JSON.parse(response.body)['text']).to include("don't have any goals")
          end
        end
      end

      context 'when command is empty' do
        let(:text) { '' }

        it 'returns help message' do
          params_hash, raw_body, sig = build_request_params(text)
          setup_request_with_signature(params_hash, raw_body, sig)
          post :create, params: params_hash
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['text']).to include('OurGruuv Slack Commands')
          expect(JSON.parse(response.body)['text']).to include('feedback')
          expect(JSON.parse(response.body)['text']).to include('huddle')
          expect(JSON.parse(response.body)['text']).to include('goal-check')
        end
      end

      context 'when command is help' do
        let(:text) { 'help' }

        it 'returns help message' do
          params_hash, raw_body, sig = build_request_params(text)
          setup_request_with_signature(params_hash, raw_body, sig)
          post :create, params: params_hash
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['text']).to include('OurGruuv Slack Commands')
        end
      end

      context 'when command is unknown' do
        let(:text) { 'unknown-command' }

        it 'returns help message' do
          params_hash, raw_body, sig = build_request_params(text)
          setup_request_with_signature(params_hash, raw_body, sig)
          post :create, params: params_hash
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['text']).to include('Unknown command')
          expect(JSON.parse(response.body)['text']).to include('OurGruuv Slack Commands')
        end
      end

      context 'when organization is not found' do
        let(:team_id) { 'T999999' }
        let(:text) { 'feedback test' }
        
        before do
          # Ensure no organization exists with this team_id
          Organization.where(slack_configurations: { workspace_id: team_id }).joins(:slack_configuration).destroy_all
        end

        it 'returns error message' do
          params_hash, raw_body, sig = build_request_params(text)
          setup_request_with_signature(params_hash, raw_body, sig)
          post :create, params: params_hash
          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['text']).to include('Organization not found')
        end
      end
    end

    context 'with invalid signature' do
      it 'returns unauthorized' do
        params_hash, raw_body, _sig = build_request_params(text)
        request.headers['X-Slack-Request-Timestamp'] = timestamp
        request.headers['X-Slack-Signature'] = 'v0=invalid-signature'
        allow_any_instance_of(ActionDispatch::Request).to receive(:raw_post).and_return(raw_body)
        post :create, params: params_hash
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with missing signature' do
      it 'returns unauthorized' do
        params_hash, raw_body, _sig = build_request_params(text)
        request.headers['X-Slack-Request-Timestamp'] = timestamp
        request.headers['X-Slack-Signature'] = nil
        allow_any_instance_of(ActionDispatch::Request).to receive(:raw_post).and_return(raw_body)
        post :create, params: params_hash
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with old timestamp' do
      let(:timestamp) { (Time.now.to_i - 400).to_s } # More than 5 minutes ago

      it 'returns unauthorized' do
        params_hash, raw_body, sig = build_request_params(text)
        setup_request_with_signature(params_hash, raw_body, sig)
        post :create, params: params_hash
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end

