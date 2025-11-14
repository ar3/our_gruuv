require 'rails_helper'

RSpec.describe ApplicationController, type: :controller do
  controller do
    def test_detect_timezone
      render plain: TimezoneService.detect_from_request(request)
    end

    def test_map_locale_to_timezone
      locale = params[:locale]
      render plain: TimezoneService.map_locale_to_timezone(locale) || 'nil'
    end

    def test_authorize
      record = params[:record_type].constantize.find(params[:record_id])
      query = params[:query]&.to_sym
      options = params[:options]&.permit!.to_h || {}
      authorize(record, query, **options)
      render plain: 'authorized'
    end
  end

  before do
    routes.draw do
      get 'test_detect_timezone' => 'anonymous#test_detect_timezone'
      get 'test_map_locale_to_timezone' => 'anonymous#test_map_locale_to_timezone'
      post 'test_authorize' => 'anonymous#test_authorize'
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

  describe '#authorize' do
    let(:organization) { create(:organization, :company) }
    let(:person) { create(:person) }
    let(:teammate) { create(:teammate, person: person, organization: organization, type: 'CompanyTeammate') }
    let(:huddle) { create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization)) }

    before do
      session[:current_company_teammate_id] = teammate.id
    end

    it 'forwards all keyword arguments to Pundit without InvalidConstructorError' do
      # This test ensures that the authorize method override properly forwards all keyword arguments
      # using **options, which prevents Pundit::InvalidConstructorError
      # The fix was changing from policy_class: nil to **options to forward all kwargs
      expect {
        post :test_authorize, params: {
          record_type: 'Huddle',
          record_id: huddle.id,
          query: 'join?'
        }
      }.not_to raise_error(Pundit::InvalidConstructorError)
      
      expect(response).to have_http_status(:success)
      expect(controller.instance_variable_get(:@_pundit_policy_record)).to eq(huddle)
    end

    it 'sets instance variables for custom redirects' do
      post :test_authorize, params: {
        record_type: 'Huddle',
        record_id: huddle.id,
        query: 'join?'
      }
      
      expect(controller.instance_variable_get(:@_pundit_policy_record)).to eq(huddle)
      expect(controller.instance_variable_get(:@_pundit_policy_query)).to eq(:join?)
    end

    it 'works with unauthenticated users' do
      session[:current_company_teammate_id] = nil
      
      # join? should allow unauthenticated access
      expect {
        post :test_authorize, params: {
          record_type: 'Huddle',
          record_id: huddle.id,
          query: 'join?'
        }
      }.not_to raise_error(Pundit::InvalidConstructorError)
      
      expect(response).to have_http_status(:success)
    end

    it 'defaults query to action name when not provided' do
      # When query is nil, it should default to action name + "?"
      # But since test_authorize? doesn't exist on HuddlePolicy, we'll get NotAuthorizedError
      # which is expected - the important thing is it doesn't raise InvalidConstructorError
      expect {
        post :test_authorize, params: {
          record_type: 'Huddle',
          record_id: huddle.id
        }
      }.not_to raise_error(Pundit::InvalidConstructorError)
      
      # Should have attempted to use test_authorize? as the query (stored as string)
      expect(controller.instance_variable_get(:@_pundit_policy_query)).to eq('test_authorize?')
    end
  end
end 