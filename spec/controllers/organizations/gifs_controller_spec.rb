require 'rails_helper'

RSpec.describe Organizations::GifsController, type: :controller do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, organization: organization, person: person) }

  before do
    sign_in person
    session[:current_company_teammate_id] = teammate.id
  end

  describe 'GET #search' do
    let(:gateway) { instance_double(Giphy::Gateway) }
    let(:gifs) do
      [
        {
          id: 'abc123',
          title: 'Test GIF',
          url: 'https://media.giphy.com/media/abc123/giphy.gif',
          preview_url: 'https://media.giphy.com/media/abc123/200w.gif'
        }
      ]
    end

    before do
      allow(Giphy::Gateway).to receive(:new).and_return(gateway)
    end

    context 'with valid query' do
      before do
        allow(gateway).to receive(:search_gifs).and_return(gifs)
      end

      it 'returns JSON with GIFs' do
        get :search, params: { organization_id: organization.id, q: 'test' }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['gifs']).to be_an(Array)
        expect(json['gifs'].length).to eq(1)
      end
    end

    context 'with empty query' do
      it 'returns bad request' do
        get :search, params: { organization_id: organization.id, q: '' }
        
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to include('required')
      end
    end

    context 'when gateway raises retryable error' do
      before do
        allow(gateway).to receive(:search_gifs).and_raise(Giphy::Gateway::RetryableError.new('Rate limited'))
      end

      it 'returns service unavailable' do
        get :search, params: { organization_id: organization.id, q: 'test' }
        
        expect(response).to have_http_status(:service_unavailable)
      end
    end

    context 'when gateway raises non-retryable error' do
      before do
        allow(gateway).to receive(:search_gifs).and_raise(Giphy::Gateway::NonRetryableError.new('Invalid API key'))
      end

      it 'returns bad request' do
        get :search, params: { organization_id: organization.id, q: 'test' }
        
        expect(response).to have_http_status(:bad_request)
        json = JSON.parse(response.body)
        expect(json['error']).to include('Invalid API key')
      end
    end

    context 'authorization' do
      it 'authorizes using ObservationPolicy#search?' do
        expect_any_instance_of(ObservationPolicy).to receive(:search?).and_return(true)
        allow(gateway).to receive(:search_gifs).and_return(gifs)
        
        get :search, params: { organization_id: organization.id, q: 'test' }
        
        expect(response).to have_http_status(:success)
      end

      context 'when not authorized' do
        before do
          allow_any_instance_of(ObservationPolicy).to receive(:search?).and_return(false)
        end

        it 'raises Pundit::NotAuthorizedError' do
          expect {
            get :search, params: { organization_id: organization.id, q: 'test' }
          }.to raise_error(Pundit::NotAuthorizedError)
        end
      end
    end
  end
end

