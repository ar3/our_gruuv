require 'rails_helper'

RSpec.describe AsanaService do
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, organization: organization) }
  let(:identity) { create(:teammate_identity, :asana, teammate: teammate) }
  let(:service) { AsanaService.new(teammate) }

  describe '.task_url' do
    it 'generates task URL with project ID' do
      url = AsanaService.task_url('123456789', '987654321')
      expect(url).to eq('https://app.asana.com/0/987654321/123456789')
    end

    it 'generates task URL without project ID' do
      url = AsanaService.task_url('123456789')
      expect(url).to eq('https://app.asana.com/0/0/123456789')
    end

    it 'generates task URL with nil project ID' do
      url = AsanaService.task_url('123456789', nil)
      expect(url).to eq('https://app.asana.com/0/0/123456789')
    end
  end

  describe '#fetch_project_sections' do
    context 'when not authenticated' do
      it 'returns error response' do
        result = service.fetch_project_sections('123')
        expect(result[:success]).to be false
        expect(result[:error]).to eq('not_authenticated')
      end
    end

    context 'when authenticated' do
      before do
        identity
        allow(service).to receive(:authenticated?).and_return(true)
        allow(service).to receive(:access_token).and_return('test_token')
      end

      context 'with successful response' do
        it 'returns sections' do
          response_body = { 'data' => [{ 'gid' => '1', 'name' => 'Section 1' }] }.to_json
          response = double(status: 200, body: double(to_s: response_body))
          allow(HTTP).to receive(:auth).and_return(double(get: response))

          result = service.fetch_project_sections('123')
          expect(result[:success]).to be true
          expect(result[:sections]).to eq([{ 'gid' => '1', 'name' => 'Section 1' }])
        end
      end

      context 'with 401 Unauthorized (token expired)' do
        it 'returns token_expired error when refresh fails' do
          error_body = { 'errors' => [{ 'message' => 'Token expired' }] }.to_json
          response = double(status: 401, body: double(to_s: error_body))
          allow(HTTP).to receive(:auth).and_return(double(get: response))
          allow(service).to receive(:refresh_access_token).and_return(false)

          result = service.fetch_project_sections('123')
          expect(result[:success]).to be false
          expect(result[:error]).to eq('token_expired')
        end

        it 'retries request after successful token refresh' do
          error_body = { 'errors' => [{ 'message' => 'Token expired' }] }.to_json
          success_body = { 'data' => [{ 'gid' => '1', 'name' => 'Section 1' }] }.to_json
          
          expired_response = double(status: 401, body: double(to_s: error_body))
          success_response = double(status: 200, body: double(to_s: success_body))
          
          allow(HTTP).to receive(:auth).and_return(double(get: expired_response))
          allow(service).to receive(:refresh_access_token).and_return(true)
          
          # After refresh, retry should succeed
          allow(HTTP).to receive(:auth).and_return(double(get: success_response))
          
          result = service.fetch_project_sections('123')
          expect(result[:success]).to be true
        end
      end

      context 'with 403 Forbidden' do
        it 'returns permission_denied error' do
          error_body = { 'errors' => [{ 'message' => 'Permission denied' }] }.to_json
          response = double(status: 403, body: double(to_s: error_body))
          allow(HTTP).to receive(:auth).and_return(double(get: response))

          result = service.fetch_project_sections('123')
          expect(result[:success]).to be false
          expect(result[:error]).to eq('permission_denied')
        end
      end

      context 'with 404 Not Found' do
        it 'returns not_found error' do
          error_body = { 'errors' => [{ 'message' => 'Not found' }] }.to_json
          response = double(status: 404, body: double(to_s: error_body))
          allow(HTTP).to receive(:auth).and_return(double(get: response))

          result = service.fetch_project_sections('123')
          expect(result[:success]).to be false
          expect(result[:error]).to eq('not_found')
        end
      end

      context 'with network error' do
        it 'returns network_error' do
          http_double = double
          allow(HTTP).to receive(:auth).and_return(http_double)
          allow(http_double).to receive(:get).and_raise(StandardError.new('Connection failed'))

          result = service.fetch_project_sections('123')
          expect(result[:success]).to be false
          expect(result[:error]).to eq('network_error')
        end
      end
    end
  end

  describe '#refresh_access_token' do
    before do
      identity
      allow(service).to receive(:refresh_token).and_return('refresh_token_123')
      allow(ENV).to receive(:[]).with('ASANA_CLIENT_ID').and_return('client_id')
      allow(ENV).to receive(:[]).with('ASANA_CLIENT_SECRET').and_return('client_secret')
    end

    context 'when refresh token is available' do
      it 'refreshes token successfully' do
        response_body = {
          'access_token' => 'new_token',
          'refresh_token' => 'new_refresh_token',
          'expires_in' => 3600
        }.to_json
        response = double(body: double(to_s: response_body))
        allow(HTTP).to receive(:post).and_return(response)
        allow(identity).to receive(:save).and_return(true)

        result = service.refresh_access_token
        expect(result).to be true
      end

      it 'returns false when refresh fails' do
        response_body = { 'error' => 'Invalid refresh token' }.to_json
        response = double(body: double(to_s: response_body))
        allow(HTTP).to receive(:post).and_return(response)

        result = service.refresh_access_token
        expect(result).to be false
      end
    end

    context 'when refresh token is not available' do
      it 'returns false' do
        allow(service).to receive(:refresh_token).and_return(nil)
        result = service.refresh_access_token
        expect(result).to be false
      end
    end
  end
end

