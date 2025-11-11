require 'rails_helper'

RSpec.describe NotificationApiService, type: :service do
  let(:client_id) { 'test_client_id' }
  let(:client_secret) { 'test_client_secret' }
  let(:service) { NotificationApiService.new(client_id: client_id, client_secret: client_secret) }
  let(:mock_response) { instance_double(HTTP::Response) }

  describe '#test_connection' do
    context 'when connection is successful' do
      before do
        auth_double = double
        headers_double = double
        allow(HTTP).to receive(:basic_auth).with(user: client_id, pass: client_secret).and_return(auth_double)
        allow(auth_double).to receive(:headers).with('Content-Type' => 'application/json').and_return(headers_double)
        allow(headers_double).to receive(:post).and_return(mock_response)
        allow(mock_response).to receive(:status).and_return(200)
        allow(mock_response).to receive(:body).and_return(double(to_s: '{"success": true}'))
        allow(JSON).to receive(:parse).with('{"success": true}').and_return({ 'success' => true })
      end

      it 'sends test notification with correct structure' do
        auth_double = double
        headers_double = double
        allow(HTTP).to receive(:basic_auth).with(user: client_id, pass: client_secret).and_return(auth_double)
        allow(auth_double).to receive(:headers).with('Content-Type' => 'application/json').and_return(headers_double)
        
        post_double = double
        body_captured = nil
        allow(headers_double).to receive(:post) do |url, options|
          expect(url).to eq("https://api.notificationapi.com/#{client_id}/sender")
          # Service uses body: (string), not json: (hash)
          body_captured = options[:body]
          post_double
        end
        
        allow(post_double).to receive(:status).and_return(200)
        allow(post_double).to receive(:body).and_return(double(to_s: '{"success": true}'))
        # Stub JSON.parse to handle both the request body (any string) and response
        allow(JSON).to receive(:parse) do |json_string|
          if json_string == '{"success": true}'
            { 'success' => true }
          else
            # For request body validation, use real JSON.parse
            JSON.parse(json_string)
          end
        end

        result = service.test_connection

        # Validate the request body string contains expected values
        # Note: service uses default parameters: to: { id: 'ar3@ar3.me', number: '+13172898859' }
        expect(body_captured).to include('"type":"initial_test"')
        expect(body_captured).to include('"id":"ar3@ar3.me"')
        expect(body_captured).to include('"number":"+13172898859"')  # Default from service
        expect(body_captured).to include('"message":"Hello, world!"')
        expect(result).to eq({ 'success' => true })
      end
    end

    context 'when connection fails' do
      before do
        auth_double = double
        headers_double = double
        allow(HTTP).to receive(:basic_auth).with(user: client_id, pass: client_secret).and_return(auth_double)
        allow(auth_double).to receive(:headers).with('Content-Type' => 'application/json').and_return(headers_double)
        allow(headers_double).to receive(:post).and_return(mock_response)
        allow(mock_response).to receive(:status).and_return(401)
        allow(mock_response).to receive(:body).and_return(double(to_s: '{"error": "Unauthorized"}'))
        allow(mock_response).to receive(:headers).and_return({})
      end

      it 'returns false' do
        result = service.test_connection
        expect(result[:success]).to be false
      end
    end

    context 'when an exception occurs' do
      before do
        allow(HTTP).to receive(:basic_auth).and_raise(StandardError.new('Network error'))
      end

      it 'returns false' do
        result = service.test_connection
        expect(result[:success]).to be false
        expect(result[:error]).to eq('Network error')
      end
    end
  end

  describe '#send_notification' do
    let(:notification_type) { 'test_notification' }
    let(:to) { { id: 'user123', number: '+1234567890' } }
    let(:sms_params) { { message: 'Hello, world!' } }

    context 'when notification is sent successfully' do
      before do
        auth_double = double
        headers_double = double
        allow(HTTP).to receive(:basic_auth).with(user: client_id, pass: client_secret).and_return(auth_double)
        allow(auth_double).to receive(:headers).with('Content-Type' => 'application/json').and_return(headers_double)
        allow(headers_double).to receive(:post).and_return(mock_response)
        allow(mock_response).to receive(:status).and_return(200)
        allow(mock_response).to receive(:body).and_return(double(to_s: '{"id": "notif_123"}'))
        allow(JSON).to receive(:parse).with('{"id": "notif_123"}').and_return({ 'id' => 'notif_123' })
      end

      it 'returns success with response data' do
        result = service.send_notification(
          type: notification_type,
          to: to,
          sms: sms_params
        )

        expect(result[:success]).to be true
        expect(result[:response]).to eq({ 'id' => 'notif_123' })
      end

      it 'includes channel-specific parameters in payload' do
        auth_double = double
        headers_double = double
        allow(HTTP).to receive(:basic_auth).with(user: client_id, pass: client_secret).and_return(auth_double)
        allow(auth_double).to receive(:headers).with('Content-Type' => 'application/json').and_return(headers_double)
        
        post_double = double
        body_captured = nil
        allow(headers_double).to receive(:post) do |url, options|
          # Service uses body: (string), not json: (hash)
          body_captured = options[:body]
          post_double
        end
        
        allow(post_double).to receive(:status).and_return(200)
        allow(post_double).to receive(:body).and_return(double(to_s: '{"id": "notif_123"}'))
        # Stub JSON.parse only for the response, not for the request body
        allow(JSON).to receive(:parse).with('{"id": "notif_123"}').and_return({ 'id' => 'notif_123' })
        # Allow real JSON.parse for request body validation
        allow(JSON).to receive(:parse).and_call_original

        service.send_notification(
          type: notification_type,
          to: to,
          sms: sms_params
        )
        
        # Validate the request body after the call (using real JSON.parse)
        payload = JSON.parse(body_captured)
        expect(payload['type']).to eq(notification_type)
        expect(payload['to']).to eq(to.stringify_keys)
        expect(payload['sms']).to eq(sms_params.stringify_keys)
      end
    end

    context 'when notification fails' do
      before do
        auth_double = double
        headers_double = double
        allow(HTTP).to receive(:basic_auth).with(user: client_id, pass: client_secret).and_return(auth_double)
        allow(auth_double).to receive(:headers).with('Content-Type' => 'application/json').and_return(headers_double)
        allow(headers_double).to receive(:post).and_return(mock_response)
        allow(mock_response).to receive(:status).and_return(400)
        allow(mock_response).to receive(:body).and_return(double(to_s: '{"error": "Invalid request"}'))
      end

      it 'returns failure with error message' do
        result = service.send_notification(
          type: notification_type,
          to: to,
          sms: sms_params
        )

        expect(result[:success]).to be false
        expect(result[:error]).to include('HTTP 400')
      end
    end

    context 'when an exception occurs' do
      before do
        allow(HTTP).to receive(:basic_auth).and_raise(StandardError.new('Network error'))
      end

      it 'returns failure with error message' do
        result = service.send_notification(
          type: notification_type,
          to: to,
          sms: sms_params
        )

        expect(result[:success]).to be false
        expect(result[:error]).to eq('Network error')
      end
    end
  end
end

