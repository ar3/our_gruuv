require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    def test_detect_timezone
      render plain: detect_timezone_from_request
    end

    def test_map_locale_to_timezone
      locale = params[:locale]
      render plain: map_locale_to_timezone(locale) || 'nil'
    end
  end

  before do
    routes.draw do
      get 'test_detect_timezone' => 'anonymous#test_detect_timezone'
      get 'test_map_locale_to_timezone' => 'anonymous#test_map_locale_to_timezone'
    end
  end

  describe '#detect_timezone_from_request' do
    it 'returns Eastern Time when no Accept-Language header' do
      get :test_detect_timezone
      expect(response.body).to eq('Eastern Time (US & Canada)')
    end

    it 'maps en-US locale to Eastern Time' do
      request.headers['Accept-Language'] = 'en-US,en;q=0.9'
      get :test_detect_timezone
      expect(response.body).to eq('Eastern Time (US & Canada)')
    end

    it 'maps en-GB locale to London' do
      request.headers['Accept-Language'] = 'en-GB,en;q=0.9'
      get :test_detect_timezone
      expect(response.body).to eq('London')
    end

    it 'maps fr-FR locale to Paris' do
      request.headers['Accept-Language'] = 'fr-FR,fr;q=0.9'
      get :test_detect_timezone
      expect(response.body).to eq('Paris')
    end

    it 'handles complex Accept-Language header' do
      request.headers['Accept-Language'] = 'en-US,en;q=0.9,es;q=0.8'
      get :test_detect_timezone
      expect(response.body).to eq('Eastern Time (US & Canada)')
    end

    it 'returns Eastern Time for unknown locale' do
      request.headers['Accept-Language'] = 'xx-XX'
      get :test_detect_timezone
      expect(response.body).to eq('Eastern Time (US & Canada)')
    end
  end

  describe '#map_locale_to_timezone' do
    it 'maps en-US to Eastern Time' do
      get :test_map_locale_to_timezone, params: { locale: 'en-US' }
      expect(response.body).to eq('Eastern Time (US & Canada)')
    end

    it 'maps en-CA to Eastern Time' do
      get :test_map_locale_to_timezone, params: { locale: 'en-CA' }
      expect(response.body).to eq('Eastern Time (US & Canada)')
    end

    it 'maps en-GB to London' do
      get :test_map_locale_to_timezone, params: { locale: 'en-GB' }
      expect(response.body).to eq('London')
    end

    it 'maps fr-FR to Paris' do
      get :test_map_locale_to_timezone, params: { locale: 'fr-FR' }
      expect(response.body).to eq('Paris')
    end

    it 'maps es-MX to Central Time' do
      get :test_map_locale_to_timezone, params: { locale: 'es-MX' }
      expect(response.body).to eq('Central Time (US & Canada)')
    end

    it 'returns nil for unknown locale' do
      get :test_map_locale_to_timezone, params: { locale: 'xx-XX' }
      expect(response.body).to eq('nil')
    end

    it 'handles nil locale' do
      get :test_map_locale_to_timezone, params: { locale: nil }
      expect(response.body).to eq('nil')
    end
  end
end 