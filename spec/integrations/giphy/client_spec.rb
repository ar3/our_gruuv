require 'rails_helper'

RSpec.describe Giphy::Client do
  let(:api_key) { 'test_api_key' }
  let(:client) { Giphy::Client.new(api_key: api_key) }
  let(:mock_response) { instance_double(HTTP::Response) }

  describe '#search' do
    context 'when request is successful' do
      let(:response_body) { '{"data": [{"id": "test123"}]}' }

      before do
        allow(HTTP).to receive(:get).and_return(mock_response)
        allow(mock_response).to receive(:status).and_return(200)
        allow(mock_response).to receive(:body).and_return(double(to_s: response_body))
        allow(JSON).to receive(:parse).with(response_body).and_return({ 'data' => [{ 'id' => 'test123' }] })
      end

      it 'returns parsed JSON response' do
        result = client.search(query: 'test', limit: 25)
        expect(result).to eq({ 'data' => [{ 'id' => 'test123' }] })
      end

      it 'calls GIPHY API with correct parameters' do
        expect(HTTP).to receive(:get).with(
          'https://api.giphy.com/v1/gifs/search',
          params: { api_key: api_key, q: 'test', limit: 25 }
        ).and_return(mock_response)
        
        client.search(query: 'test', limit: 25)
      end
    end

    context 'when rate limited' do
      before do
        allow(HTTP).to receive(:get).and_return(mock_response)
        allow(mock_response).to receive(:status).and_return(429)
        allow(mock_response).to receive(:headers).and_return({ 'Retry-After' => '60' })
      end

      it 'raises RateLimited error' do
        expect {
          client.search(query: 'test')
        }.to raise_error(Giphy::Client::RateLimited) do |error|
          expect(error.retry_after_seconds).to eq(60)
        end
      end
    end

    context 'when unauthorized' do
      before do
        allow(HTTP).to receive(:get).and_return(mock_response)
        allow(mock_response).to receive(:status).and_return(401)
      end

      it 'raises Unauthorized error' do
        expect {
          client.search(query: 'test')
        }.to raise_error(Giphy::Client::Unauthorized, /Invalid API key/)
      end
    end

    context 'when network error occurs' do
      before do
        allow(HTTP).to receive(:get).and_raise(SocketError.new('Connection failed'))
      end

      it 'raises NetworkError' do
        expect {
          client.search(query: 'test')
        }.to raise_error(Giphy::Client::NetworkError, /Network error/)
      end
    end
  end
end


