require 'rails_helper'

RSpec.describe SlackService do
  let(:organization) { create(:organization, :company) }
  let(:slack_service) { SlackService.new(organization) }
  let(:slack_config) { create(:slack_configuration, organization: organization) }

  before do
    slack_config
  end

  describe '#slack_configured?' do
    context 'when SLACK_BOT_TOKEN is set' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return('xoxb-test-token')
      end

      it 'returns true' do
        expect(slack_service.slack_configured?).to be true
      end
    end

    context 'when SLACK_BOT_TOKEN is not set' do
      before do
        allow(ENV).to receive(:[]).with('SLACK_BOT_TOKEN').and_return(nil)
        allow(organization).to receive(:slack_configured?).and_return(false)
      end

      it 'returns false' do
        expect(slack_service.slack_configured?).to be false
      end
    end
  end

  describe '#post_message' do
    let(:notification) { create(:notification, notifiable: organization, metadata: { channel: 'test-channel' }, rich_message: [{ type: 'section', text: { type: 'mrkdwn', text: 'Test message' } }], fallback_text: 'Test message') }
    let(:mock_client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when notification exists and Slack is configured' do
      before do
        allow(mock_client).to receive(:chat_postMessage).and_return({ 'ok' => true, 'ts' => '1234567890.123456' })
      end

      it 'posts message and updates notification status' do
        result = slack_service.post_message(notification.id)
        
        expect(mock_client).to have_received(:chat_postMessage).with(
          hash_including(
            channel: 'test-channel',
            text: 'Test message',
            blocks: notification.rich_message
          )
        )
        expect(result).to eq({ 
          success: true, 
          message_id: '1234567890.123456', 
          channel: 'test-channel', 
          response: { 'ok' => true, 'ts' => '1234567890.123456' } 
        })
        expect(notification.reload.status).to eq('sent_successfully')
        expect(notification.reload.message_id).to eq('1234567890.123456')
      end
    end

    context 'when notification has main_thread' do
      let(:main_thread) { create(:notification, notifiable: organization, message_id: '1234567890.123456') }
      let(:threaded_notification) { create(:notification, notifiable: organization, main_thread: main_thread, metadata: { channel: 'test-channel' }, rich_message: [{ type: 'section', text: { type: 'mrkdwn', text: 'Thread reply' } }], fallback_text: 'Thread reply') }

      before do
        allow(mock_client).to receive(:chat_postMessage).and_return({ 'ok' => true, 'ts' => '1234567890.123457' })
      end

      it 'posts message in thread' do
        result = slack_service.post_message(threaded_notification.id)
        
        expect(mock_client).to have_received(:chat_postMessage).with(
          hash_including(
            channel: 'test-channel',
            thread_ts: '1234567890.123456',
            text: 'Thread reply',
            blocks: threaded_notification.rich_message
          )
        )
        expect(result).to eq({ 
          success: true, 
          message_id: '1234567890.123457', 
          channel: 'test-channel', 
          response: { 'ok' => true, 'ts' => '1234567890.123457' } 
        })
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:chat_postMessage).and_raise(Slack::Web::Api::Errors::SlackError.new('API Error'))
      end

      it 'updates notification status to failed' do
        result = slack_service.post_message(notification.id)
        
        expect(result).to eq({ success: false, error: 'API Error', channel: 'test-channel' })
        expect(notification.reload.status).to eq('send_failed')
      end
    end

    context 'when notification does not exist' do
      it 'returns error hash' do
        result = slack_service.post_message(999999)
        expect(result).to eq({ success: false, error: 'Notification 999999 not found' })
      end
    end
  end

  describe '#update_message' do
    let(:original_notification) { create(:notification, notifiable: organization, message_id: '1234567890.123456') }
    let(:update_notification) { create(:notification, notifiable: organization, original_message: original_notification, metadata: { channel: 'test-channel' }, rich_message: [{ type: 'section', text: { type: 'mrkdwn', text: 'Updated message' } }], fallback_text: 'Updated message') }
    let(:mock_client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when notification exists and Slack is configured' do
      before do
        allow(mock_client).to receive(:chat_update).and_return({ 'ok' => true })
      end

      it 'updates message and updates notification status' do
        result = slack_service.update_message(update_notification.id)
        
        expect(mock_client).to have_received(:chat_update).with(
          hash_including(
            channel: 'test-channel',
            ts: '1234567890.123456',
            text: 'Updated message',
            blocks: update_notification.rich_message
          )
        )
        expect(result).to eq({ 
          success: true, 
          message_id: '1234567890.123456', 
          channel: 'test-channel', 
          response: { 'ok' => true } 
        })
        expect(update_notification.reload.status).to eq('sent_successfully')
        expect(update_notification.reload.message_id).to eq('1234567890.123456')
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:chat_update).and_raise(Slack::Web::Api::Errors::SlackError.new('API Error'))
      end

      it 'updates notification status to failed' do
        result = slack_service.update_message(update_notification.id)
        
        expect(result).to eq({ success: false, error: 'API Error', channel: 'test-channel' })
        expect(update_notification.reload.status).to eq('send_failed')
      end
    end

    context 'when notification does not exist' do
      it 'returns error hash' do
        result = slack_service.update_message(999999)
        expect(result).to eq({ success: false, error: 'Notification 999999 not found' })
      end
    end

    context 'when original message does not exist' do
      let(:update_notification) { create(:notification, notifiable: organization, original_message: nil, metadata: { channel: 'test-channel' }, rich_message: [{ type: 'section', text: { type: 'mrkdwn', text: 'Updated message' } }], fallback_text: 'Updated message') }

      it 'returns error hash' do
        result = slack_service.update_message(update_notification.id)
        expect(result).to eq({ success: false, error: 'Original message not found' })
      end
    end
  end

  describe '#test_connection' do
    let(:mock_client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when Slack is not configured' do
      before do
        allow(slack_service).to receive(:slack_configured?).and_return(false)
      end

      it 'returns failure hash with error' do
        result = slack_service.test_connection
        expect(result).to eq({ 'success' => false, 'error' => 'Slack not configured', 'steps' => {} })
      end
    end

    context 'when connection is successful' do
      before do
        allow(mock_client).to receive(:auth_test).and_return({ 'ok' => true, 'team' => 'Test Team', 'team_id' => 'T123456' })
        allow(mock_client).to receive(:conversations_list).and_return(
          { 'ok' => true, 'channels' => [{ 'id' => 'C1', 'name' => 'general' }], 'response_metadata' => {} }
        )
        allow(mock_client).to receive(:users_list).and_return(
          { 'ok' => true, 'members' => [{ 'id' => 'U1', 'name' => 'user1' }], 'response_metadata' => {} }
        )
        allow(mock_client).to receive(:chat_postMessage).and_return({ 'ok' => true, 'ts' => '1234567890.123456' })
      end

      it 'returns success hash with team, team_id, and steps (auth, channels, users, test_message)' do
        result = slack_service.test_connection
        expect(result['success']).to be true
        expect(result['team']).to eq('Test Team')
        expect(result['team_id']).to eq('T123456')
        expect(result['steps']['auth']).to eq({ 'success' => true })
        expect(result['steps']['channels']['success']).to be true
        expect(result['steps']['channels']['count']).to eq(1)
        expect(result['steps']['users']['success']).to be true
        expect(result['steps']['users']['count']).to eq(1)
        expect(result['steps']['test_message']['success']).to be true
      end
    end

    context 'when auth fails' do
      before do
        allow(mock_client).to receive(:auth_test).and_raise(Slack::Web::Api::Errors::SlackError.new('Auth failed'))
      end

      it 'returns failure hash with steps.auth failure' do
        result = slack_service.test_connection
        expect(result['success']).to be false
        expect(result['error']).to eq('Connection test failed')
        expect(result['steps']['auth']).to eq({ 'success' => false, 'error' => 'Auth failed' })
      end
    end

    context 'when auth succeeds but list_channels fails' do
      before do
        allow(mock_client).to receive(:auth_test).and_return({ 'ok' => true, 'team' => 'Test Team', 'team_id' => 'T123456' })
        # Raise an error that is not rescued by list_channels (it only rescues SlackError and returns [])
        allow(mock_client).to receive(:conversations_list).and_raise(StandardError.new('channel_error'))
        allow(mock_client).to receive(:users_list).and_return(
          { 'ok' => true, 'members' => [], 'response_metadata' => {} }
        )
        allow(mock_client).to receive(:chat_postMessage).and_return({ 'ok' => true, 'ts' => '1234567890.123456' })
      end

      it 'returns success with channels step failed' do
        result = slack_service.test_connection
        expect(result['success']).to be true
        expect(result['steps']['channels']['success']).to be false
        expect(result['steps']['channels']['error']).to include('channel_error')
        expect(result['steps']['users']['success']).to be true
        expect(result['steps']['test_message']['success']).to be true
      end
    end
  end



  describe '#post_test_message' do
    let(:mock_client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
      allow(mock_client).to receive(:chat_postMessage).and_return({ 'ok' => true, 'ts' => '1234567890.123456' })
    end

    context 'when Slack is configured' do
      it 'posts test message successfully' do
        result = slack_service.post_test_message('Test message')
        expect(result[:success]).to be true
        expect(result[:message]).to eq('Test message sent successfully')
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(slack_service).to receive(:slack_configured?).and_return(false)
      end

      it 'returns error message' do
        result = slack_service.post_test_message('Test message')
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Slack not configured')
      end
    end
  end

  describe '#list_users' do
    let(:mock_client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when Slack is configured' do
      let(:users_response) do
        {
          'ok' => true,
          'members' => [
            {
              'id' => 'U123456',
              'name' => 'testuser',
              'profile' => {
                'email' => 'test@example.com',
                'real_name' => 'Test User',
                'image_512' => 'https://slack.com/avatar512.jpg'
              }
            },
            {
              'id' => 'U789012',
              'name' => 'anotheruser',
              'profile' => {
                'email' => 'another@example.com',
                'real_name' => 'Another User',
                'image_192' => 'https://slack.com/avatar192.jpg'
              }
            }
          ],
          'response_metadata' => { 'next_cursor' => nil }
        }
      end

      before do
        allow(mock_client).to receive(:users_list).and_return(users_response)
      end

      it 'returns list of users' do
        result = slack_service.list_users
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first['id']).to eq('U123456')
      end

      it 'handles pagination' do
        first_page = users_response.dup
        second_page = {
          'ok' => true,
          'members' => [
            {
              'id' => 'U345678',
              'name' => 'thirduser',
              'profile' => { 'email' => 'third@example.com', 'real_name' => 'Third User' }
            }
          ],
          'response_metadata' => { 'next_cursor' => nil }
        }

        allow(mock_client).to receive(:users_list).with({ limit: 1000 }).and_return(first_page)
        allow(mock_client).to receive(:users_list).with({ limit: 1000, cursor: 'cursor123' }).and_return(second_page)

        first_page['response_metadata']['next_cursor'] = 'cursor123'

        result = slack_service.list_users
        expect(result.length).to eq(3)
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:users_list).and_raise(Slack::Web::Api::Errors::SlackError.new('API Error'))
      end

      it 'returns empty array' do
        result = slack_service.list_users
        expect(result).to eq([])
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(slack_service).to receive(:slack_configured?).and_return(false)
      end

      it 'returns empty array' do
        result = slack_service.list_users
        expect(result).to eq([])
      end
    end
  end
  
  describe '#list_groups' do
    let(:mock_client) { instance_double(Slack::Web::Client) }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when Slack is configured' do
      let(:groups_response) do
        {
          'ok' => true,
          'usergroups' => [
            {
              'id' => 'S123456',
              'name' => 'Engineering',
              'handle' => 'engineering'
            },
            {
              'id' => 'S789012',
              'name' => 'Product',
              'handle' => 'product'
            }
          ],
          'response_metadata' => { 'next_cursor' => nil }
        }
      end

      before do
        allow(mock_client).to receive(:usergroups_list).and_return(groups_response)
      end

      it 'returns list of groups' do
        result = slack_service.list_groups
        expect(result).to be_an(Array)
        expect(result.length).to eq(2)
        expect(result.first['id']).to eq('S123456')
      end

      it 'handles pagination' do
        first_page = groups_response.dup
        second_page = {
          'ok' => true,
          'usergroups' => [
            {
              'id' => 'S345678',
              'name' => 'Design',
              'handle' => 'design'
            }
          ],
          'response_metadata' => { 'next_cursor' => nil }
        }

        allow(mock_client).to receive(:usergroups_list).with({ include_users: false }).and_return(first_page)
        allow(mock_client).to receive(:usergroups_list).with({ include_users: false, cursor: 'cursor123' }).and_return(second_page)

        first_page['response_metadata']['next_cursor'] = 'cursor123'

        result = slack_service.list_groups
        expect(result.length).to eq(3)
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:usergroups_list).and_raise(Slack::Web::Api::Errors::SlackError.new('API Error'))
      end

      it 'returns empty array' do
        result = slack_service.list_groups
        expect(result).to eq([])
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(slack_service).to receive(:slack_configured?).and_return(false)
      end

      it 'returns empty array' do
        result = slack_service.list_groups
        expect(result).to eq([])
      end
    end
  end

  describe '#get_message_permalink' do
    let(:mock_client) { instance_double(Slack::Web::Client) }
    let(:channel_id) { 'C123456' }
    let(:message_ts) { '1234567890.123456' }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when Slack is configured' do
      before do
        allow(mock_client).to receive(:chat_getPermalink).and_return({
          'ok' => true,
          'permalink' => 'https://slack.com/archives/C123456/p1234567890123456'
        })
      end

      it 'returns permalink successfully' do
        result = slack_service.get_message_permalink(channel_id, message_ts)
        
        expect(result[:success]).to be true
        expect(result[:permalink]).to eq('https://slack.com/archives/C123456/p1234567890123456')
        expect(mock_client).to have_received(:chat_getPermalink).with(
          channel: channel_id,
          message_ts: message_ts
        )
      end

      it 'stores response in DebugResponse' do
        expect(slack_service).to receive(:store_slack_response).with(
          'chat_getPermalink',
          { channel: channel_id, message_ts: message_ts },
          hash_including('ok' => true, 'permalink' => kind_of(String))
        )

        slack_service.get_message_permalink(channel_id, message_ts)
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:chat_getPermalink).and_raise(Slack::Web::Api::Errors::SlackError.new('Channel not found'))
      end

      it 'returns error hash' do
        result = slack_service.get_message_permalink(channel_id, message_ts)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Channel not found')
      end

      it 'stores error in DebugResponse' do
        expect(slack_service).to receive(:store_slack_response).with(
          'chat_getPermalink',
          { channel: channel_id, message_ts: message_ts },
          hash_including(error: 'Channel not found')
        )

        slack_service.get_message_permalink(channel_id, message_ts)
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(slack_service).to receive(:slack_configured?).and_return(false)
      end

      it 'returns error hash' do
        result = slack_service.get_message_permalink(channel_id, message_ts)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Slack not configured')
      end
    end
  end

  describe '#get_message' do
    let(:mock_client) { instance_double(Slack::Web::Client) }
    let(:channel_id) { 'C123456' }
    let(:message_ts) { '1234567890.123456' }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when Slack is configured' do
      let(:messages_response) do
        {
          'ok' => true,
          'messages' => [
            {
              'type' => 'message',
              'text' => 'Hello, this is the message content.',
              'ts' => message_ts
            }
          ]
        }
      end

      before do
        allow(mock_client).to receive(:conversations_history).and_return(messages_response)
      end

      it 'returns message text successfully' do
        result = slack_service.get_message(channel_id, message_ts)

        expect(result[:success]).to be true
        expect(result[:text]).to eq('Hello, this is the message content.')
        expect(mock_client).to have_received(:conversations_history).with(
          channel: channel_id,
          latest: message_ts,
          oldest: message_ts,
          inclusive: true,
          limit: 1
        )
      end

      it 'stores response in DebugResponse' do
        expect(slack_service).to receive(:store_slack_response).with(
          'conversations_history',
          { channel: channel_id, message_ts: message_ts },
          hash_including('ok' => true, 'messages' => kind_of(Array))
        )

        slack_service.get_message(channel_id, message_ts)
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:conversations_history).and_raise(Slack::Web::Api::Errors::SlackError.new('Channel not found'))
      end

      it 'returns error hash' do
        result = slack_service.get_message(channel_id, message_ts)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Channel not found')
      end

      it 'stores error in DebugResponse' do
        expect(slack_service).to receive(:store_slack_response).with(
          'conversations_history',
          { channel: channel_id, message_ts: message_ts },
          hash_including(error: 'Channel not found')
        )

        slack_service.get_message(channel_id, message_ts)
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(slack_service).to receive(:slack_configured?).and_return(false)
      end

      it 'returns error hash' do
        result = slack_service.get_message(channel_id, message_ts)

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Slack not configured')
      end
    end
  end

  describe '#open_create_observation_modal' do
    let(:mock_client) { instance_double(Slack::Web::Client) }
    let(:trigger_id) { '1234567890.123456.abcdef' }
    let(:private_metadata) { { team_id: 'T123456', channel_id: 'C123456' }.to_json }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when Slack is configured' do
      before do
        allow(mock_client).to receive(:views_open).and_return({ 'ok' => true })
      end

      it 'opens modal successfully' do
        result = slack_service.open_create_observation_modal(trigger_id, private_metadata)
        
        expect(result[:success]).to be true
        expect(mock_client).to have_received(:views_open).with(
          hash_including(
            trigger_id: trigger_id,
            view: hash_including(
              type: 'modal',
              callback_id: 'create_observation_from_message'
            )
          )
        )
      end

      it 'stores response in DebugResponse' do
        expect(slack_service).to receive(:store_slack_response).with(
          'views_open',
          hash_including(trigger_id: trigger_id),
          hash_including('ok' => true)
        )

        slack_service.open_create_observation_modal(trigger_id, private_metadata)
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:views_open).and_raise(Slack::Web::Api::Errors::SlackError.new('Invalid trigger_id'))
      end

      it 'returns error hash' do
        result = slack_service.open_create_observation_modal(trigger_id, private_metadata)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Invalid trigger_id')
      end
    end
  end

  describe '#post_message_to_thread' do
    let(:mock_client) { instance_double(Slack::Web::Client) }
    let(:channel_id) { 'C123456' }
    let(:thread_ts) { '1234567890.123456' }
    let(:text) { 'Test thread message' }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when Slack is configured' do
      before do
        allow(mock_client).to receive(:chat_postMessage).and_return({
          'ok' => true,
          'ts' => '1234567890.123457'
        })
      end

      it 'posts message to thread successfully' do
        result = slack_service.post_message_to_thread(
          channel_id: channel_id,
          thread_ts: thread_ts,
          text: text
        )
        
        expect(result[:success]).to be true
        expect(result[:message_id]).to eq('1234567890.123457')
        expect(mock_client).to have_received(:chat_postMessage).with(
          channel: channel_id,
          thread_ts: thread_ts,
          text: text
        )
      end

      it 'stores response in DebugResponse' do
        expect(slack_service).to receive(:store_slack_response).with(
          'chat_postMessage_thread',
          { channel: channel_id, thread_ts: thread_ts, text: text },
          hash_including('ok' => true, 'ts' => kind_of(String))
        )

        slack_service.post_message_to_thread(
          channel_id: channel_id,
          thread_ts: thread_ts,
          text: text
        )
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:chat_postMessage).and_raise(Slack::Web::Api::Errors::SlackError.new('Channel not found'))
      end

      it 'returns error hash' do
        result = slack_service.post_message_to_thread(
          channel_id: channel_id,
          thread_ts: thread_ts,
          text: text
        )
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Channel not found')
      end

      it 'stores error in DebugResponse' do
        expect(slack_service).to receive(:store_slack_response).with(
          'chat_postMessage_thread',
          { channel: channel_id, thread_ts: thread_ts },
          hash_including(error: 'Channel not found')
        )

        slack_service.post_message_to_thread(
          channel_id: channel_id,
          thread_ts: thread_ts,
          text: text
        )
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(slack_service).to receive(:slack_configured?).and_return(false)
      end

      it 'returns error hash' do
        result = slack_service.post_message_to_thread(
          channel_id: channel_id,
          thread_ts: thread_ts,
          text: text
        )
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Slack not configured')
      end
    end
  end

  describe '#post_dm' do
    let(:mock_client) { instance_double(Slack::Web::Client) }
    let(:user_id) { 'U123456' }
    let(:text) { 'Test DM message' }

    before do
      allow(Slack::Web::Client).to receive(:new).and_return(mock_client)
    end

    context 'when Slack is configured' do
      before do
        allow(mock_client).to receive(:chat_postMessage).and_return({
          'ok' => true,
          'ts' => '1234567890.123458'
        })
      end

      it 'posts DM successfully' do
        result = slack_service.post_dm(user_id: user_id, text: text)
        
        expect(result[:success]).to be true
        expect(result[:message_id]).to eq('1234567890.123458')
        expect(mock_client).to have_received(:chat_postMessage).with(
          channel: user_id,
          text: text
        )
      end

      it 'stores response in DebugResponse' do
        expect(slack_service).to receive(:store_slack_response).with(
          'chat_postMessage_dm',
          { user_id: user_id, text: text },
          hash_including('ok' => true, 'ts' => kind_of(String))
        )

        slack_service.post_dm(user_id: user_id, text: text)
      end
    end

    context 'when Slack API fails' do
      before do
        allow(mock_client).to receive(:chat_postMessage).and_raise(Slack::Web::Api::Errors::SlackError.new('User not found'))
      end

      it 'returns error hash' do
        result = slack_service.post_dm(user_id: user_id, text: text)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('User not found')
      end

      it 'stores error in DebugResponse' do
        expect(slack_service).to receive(:store_slack_response).with(
          'chat_postMessage_dm',
          { user_id: user_id },
          hash_including(error: 'User not found')
        )

        slack_service.post_dm(user_id: user_id, text: text)
      end
    end

    context 'when Slack is not configured' do
      before do
        allow(slack_service).to receive(:slack_configured?).and_return(false)
      end

      it 'returns error hash' do
        result = slack_service.post_dm(user_id: user_id, text: text)
        
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Slack not configured')
      end
    end
  end
end 