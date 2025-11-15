require 'rails_helper'

RSpec.describe Giphy::Gateway do
  let(:api_key) { 'test_api_key' }
  let(:client) { instance_double(Giphy::Client) }
  let(:gateway) { Giphy::Gateway.new(client: client) }

  describe '#search_gifs' do
    context 'when API key is not configured' do
      before do
        allow(ENV).to receive(:[]).with('GIPHY_API_KEY').and_return(nil)
        allow(Giphy::Client).to receive(:new).and_return(client)
      end

      it 'raises NonRetryableError' do
        gateway_without_key = Giphy::Gateway.new
        expect {
          gateway_without_key.search_gifs(query: 'test')
        }.to raise_error(Giphy::Gateway::NonRetryableError, /not configured/)
      end
    end

    context 'when search is successful' do
      let(:giphy_response) do
        {
          'data' => [
            {
              'id' => 'abc123',
              'title' => 'Test GIF',
              'images' => {
                'original' => { 'url' => 'https://media.giphy.com/media/abc123/giphy.gif', 'width' => 480, 'height' => 270 },
                'fixed_height' => { 'url' => 'https://media.giphy.com/media/abc123/200w.gif' }
              }
            }
          ]
        }
      end

      before do
        allow(ENV).to receive(:[]).with('GIPHY_API_KEY').and_return(api_key)
        allow(client).to receive(:search).and_return(giphy_response)
      end

      it 'returns formatted GIF data' do
        result = gateway.search_gifs(query: 'test', limit: 25)
        
        expect(result).to be_an(Array)
        expect(result.length).to eq(1)
        expect(result.first).to include(
          id: 'abc123',
          title: 'Test GIF',
          url: 'https://media.giphy.com/media/abc123/giphy.gif',
          preview_url: 'https://media.giphy.com/media/abc123/200w.gif'
        )
      end
    end

    context 'when rate limited' do
      before do
        allow(ENV).to receive(:[]).with('GIPHY_API_KEY').and_return(api_key)
        allow(client).to receive(:search).and_raise(Giphy::Client::RateLimited.new('Rate limited', 60))
      end

      it 'raises RetryableError' do
        expect {
          gateway.search_gifs(query: 'test')
        }.to raise_error(Giphy::Gateway::RetryableError, /Rate limited/)
      end
    end

    context 'when unauthorized' do
      before do
        allow(ENV).to receive(:[]).with('GIPHY_API_KEY').and_return(api_key)
        allow(client).to receive(:search).and_raise(Giphy::Client::Unauthorized.new('Invalid API key'))
      end

      it 'raises NonRetryableError' do
        expect {
          gateway.search_gifs(query: 'test')
        }.to raise_error(Giphy::Gateway::NonRetryableError, /Invalid API key/)
      end
    end
  end
end


