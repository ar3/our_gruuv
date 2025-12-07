require 'rails_helper'

RSpec.describe Slack::ProcessInteractionJob, type: :job do
  let(:organization) { create(:organization, :company, :with_slack_config) }
  let(:incoming_webhook) { create(:incoming_webhook, organization: organization, status: 'unprocessed') }
  let(:observer_person) { create(:person) }
  let(:observee_person) { create(:person) }
  let(:observer_teammate) { create(:teammate, person: observer_person, organization: organization) }
  let(:observee_teammate) { create(:teammate, person: observee_person, organization: organization) }
  let(:observer_slack_id) { 'U123456' }
  let(:observee_slack_id) { 'U789012' }
  let(:team_id) { 'T123456' }
  let(:channel_id) { 'C123456' }
  let(:message_ts) { '1234567890.123456' }
  let(:notes) { 'Test observation notes' }
  
  let(:view_submission_payload) do
    {
      'type' => 'view_submission',
      'team' => { 'id' => team_id },
      'view' => {
        'callback_id' => 'create_observation_from_message',
        'private_metadata' => {
          'team_id' => team_id,
          'channel_id' => channel_id,
          'message_ts' => message_ts,
          'message_user_id' => observee_slack_id,
          'triggering_user_id' => observer_slack_id
        }.to_json,
        'state' => {
          'values' => {
            'share_in_thread' => {
              'share_in_thread' => {
                'selected_option' => {
                  'value' => 'yes'
                }
              }
            },
            'notes' => {
              'notes' => {
                'value' => notes
              }
            }
          }
        }
      }
    }
  end

  before do
    # Set up Slack workspace mapping
    slack_config = organization.slack_configuration
    slack_config.update!(workspace_id: team_id)
    
    # Set up teammate identities
    create(:teammate_identity, teammate: observer_teammate, provider: 'slack', uid: observer_slack_id)
    create(:teammate_identity, teammate: observee_teammate, provider: 'slack', uid: observee_slack_id)
    
    # Mock SlackService
    allow_any_instance_of(SlackService).to receive(:get_message_permalink).and_return({
      success: true,
      permalink: 'https://slack.com/archives/C123456/p1234567890123456'
    })
    allow_any_instance_of(SlackService).to receive(:post_message_to_thread).and_return({
      success: true,
      message_id: '1234567890.123457'
    })
    allow_any_instance_of(SlackService).to receive(:post_dm).and_return({
      success: true,
      message_id: '1234567890.123458'
    })
    allow_any_instance_of(SlackService).to receive(:store_slack_response)
  end

  describe '#perform' do
    context 'when webhook does not exist' do
      it 'returns early without error' do
        expect {
          described_class.new.perform(999999)
        }.not_to raise_error
      end
    end

    context 'when webhook is already processed' do
      let(:incoming_webhook) { create(:incoming_webhook, organization: organization, status: 'processed') }

      it 'returns early without processing' do
        expect(Slack::CreateObservationFromMessageService).not_to receive(:new)
        described_class.new.perform(incoming_webhook.id)
      end
    end

    context 'when event type is view_submission' do
      before do
        incoming_webhook.update!(payload: view_submission_payload)
        incoming_webhook.reload
      end

      context 'when callback_id matches create_observation_from_message' do
        # Use real service but mock external Slack API calls
        before do
          # Mock SlackService methods that call external API
          allow_any_instance_of(SlackService).to receive(:get_message_permalink).and_return({
            success: true,
            permalink: 'https://slack.com/archives/C123456/p1234567890123456'
          })
          allow_any_instance_of(SlackService).to receive(:post_message_to_thread).and_return({
            success: true,
            message_id: '1234567890.123457'
          })
          allow_any_instance_of(SlackService).to receive(:post_dm).and_return({
            success: true,
            message_id: '1234567890.123458'
          })
          allow_any_instance_of(SlackService).to receive(:store_slack_response)
          allow(Rails.application.routes.url_helpers).to receive(:organization_observation_url).and_return('https://example.com/observations/123')
        end

        it 'creates observation and links webhook' do
          webhook_id = incoming_webhook.id
          # Ensure webhook is fully persisted before job runs
          webhook = IncomingWebhook.find(webhook_id)
          webhook.update!(payload: view_submission_payload)
          expect(webhook.reload.status).to eq('unprocessed')
          
          # Execute job using perform_and_get_result to bypass ActiveJob framework
          job = described_class.new
          job.perform(webhook_id)
          
          # Check webhook was processed
          webhook.reload
          expect(webhook.status).to eq('processed')
          expect(Observation.count).to eq(1)
          expect(webhook.resultable).to be_a(Observation)
          expect(webhook.resultable.observer).to eq(observer_person)
        end

        context 'when share_in_thread is yes' do
          it 'posts message to thread' do
            expect_any_instance_of(SlackService).to receive(:post_message_to_thread).with(
              channel_id: channel_id,
              thread_ts: message_ts,
              text: match(/Draft observation created/)
            )

            described_class.new.perform(incoming_webhook.id)
          end

          it 'marks webhook as processed' do
            described_class.new.perform(incoming_webhook.id)
            
            expect(incoming_webhook.reload.status).to eq('processed')
          end
        end

        context 'when share_in_thread is no' do
          before do
            # Update payload to set share_in_thread to 'no'
            updated_payload = view_submission_payload.deep_dup
            updated_payload['view']['state']['values']['share_in_thread']['share_in_thread']['selected_option']['value'] = 'no'
            incoming_webhook.update!(payload: updated_payload)
            incoming_webhook.reload
          end

          it 'posts DM to triggering user' do
            expect_any_instance_of(SlackService).to receive(:post_dm).with(
              user_id: observer_slack_id,
              text: match(/Draft observation created/)
            )

            described_class.new.perform(incoming_webhook.id)
          end
        end

        context 'when observation creation fails' do
          before do
            # Make observer not found by removing the teammate identity
            TeammateIdentity.where(teammate: observer_teammate, provider: 'slack').destroy_all
          end

          it 'marks webhook as failed with error message' do
            described_class.new.perform(incoming_webhook.id)
            
            webhook = IncomingWebhook.find(incoming_webhook.id)
            expect(webhook.status).to eq('failed')
            expect(webhook.error_message).to include('Observer')
          end

          it 'does not post any messages' do
            expect_any_instance_of(SlackService).not_to receive(:post_message_to_thread)
            expect_any_instance_of(SlackService).not_to receive(:post_dm)

            described_class.new.perform(incoming_webhook.id)
          end
        end
      end

      context 'when callback_id does not match' do
        before do
          view_submission_payload['view']['callback_id'] = 'other_callback'
          incoming_webhook.update!(payload: view_submission_payload)
        end

        it 'does not process the submission' do
          expect(Slack::CreateObservationFromMessageService).not_to receive(:new)
          described_class.new.perform(incoming_webhook.id)
        end
      end
    end

    context 'when event type is message_action' do
      before do
        incoming_webhook.update!(payload: { 'type' => 'message_action' })
      end

      it 'marks webhook as failed with appropriate message' do
        described_class.new.perform(incoming_webhook.id)
        
        expect(incoming_webhook.reload.status).to eq('failed')
        expect(incoming_webhook.error_message).to include('should be handled synchronously')
      end
    end

    context 'when organization is not found' do
      before do
        # Update private_metadata to use a team_id that doesn't exist
        updated_payload = view_submission_payload.deep_dup
        updated_payload['view']['private_metadata'] = {
          'team_id' => 'T999999',
          'channel_id' => channel_id,
          'message_ts' => message_ts,
          'message_user_id' => observee_slack_id,
          'triggering_user_id' => observer_slack_id
        }.to_json
        updated_payload['team']['id'] = 'T999999'
        incoming_webhook.update!(payload: updated_payload, organization_id: nil)
        # Ensure no slack config exists for this team_id
        SlackConfiguration.where(workspace_id: 'T999999').destroy_all
      end

      it 'marks webhook as failed' do
        described_class.new.perform(incoming_webhook.id)
        
        expect(incoming_webhook.reload.status).to eq('failed')
        expect(incoming_webhook.error_message).to include('Organization not found')
      end
    end

    context 'when exception occurs' do
      let(:mock_service) { instance_double(Slack::CreateObservationFromMessageService) }

      before do
        incoming_webhook.update!(payload: view_submission_payload)
        allow(Slack::CreateObservationFromMessageService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:call).and_raise(StandardError.new('Unexpected error'))
      end

      it 'marks webhook as failed' do
        described_class.new.perform(incoming_webhook.id)
        
        expect(incoming_webhook.reload.status).to eq('failed')
        expect(incoming_webhook.error_message).to eq('Unexpected error')
      end
    end
  end
end

