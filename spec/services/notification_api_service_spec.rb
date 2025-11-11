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
        allow(headers_double).to receive(:post) do |url, options|
          expect(url).to eq('https://api.notificationapi.com/sender')
          expect(options[:json]).to include(
            type: 'initial_test',
            to: { id: 'ar3@ar3.me', number: '+15005550006' },
            sms: { message: 'Hello, world!' }
          )
          post_double
        end
        
        allow(post_double).to receive(:status).and_return(200)
        allow(post_double).to receive(:body).and_return(double(to_s: '{"success": true}'))
        allow(JSON).to receive(:parse).with('{"success": true}').and_return({ 'success' => true })

        result = service.test_connection

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
      end

      it 'returns false' do
        result = service.test_connection
        expect(result).to be false
      end
    end

    context 'when an exception occurs' do
      before do
        allow(HTTP).to receive(:basic_auth).and_raise(StandardError.new('Network error'))
      end

      it 'returns false' do
        result = service.test_connection
        expect(result).to be false
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
        allow(headers_double).to receive(:post) do |url, options|
          expect(options[:json]).to include(
            type: notification_type,
            to: to,
            sms: sms_params
          )
          post_double
        end
        
        allow(post_double).to receive(:status).and_return(200)
        allow(post_double).to receive(:body).and_return(double(to_s: '{"id": "notif_123"}'))
        allow(JSON).to receive(:parse).with('{"id": "notif_123"}').and_return({ 'id' => 'notif_123' })

        service.send_notification(
          type: notification_type,
          to: to,
          sms: sms_params
        )
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

