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
    let(:organization) { create(:organization) }
    let(:person) { create(:person) }
    let(:teammate) { create(:company_teammate, person: person, organization: organization) }
    let(:huddle) { create(:huddle, team: create(:team, company: organization)) }

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

  describe '#recent_page_visits' do
    let(:person) { create(:person) }
    let(:other_person) { create(:person) }

    before do
      session[:current_company_teammate_id] = nil
      allow(controller).to receive(:current_person).and_return(person)
    end

    context 'when person has no visits' do
      it 'returns empty array' do
        expect(controller.send(:recent_page_visits)).to eq([])
      end
    end

    context 'when person has visits' do
      let!(:most_visited1) { create(:page_visit, person: person, url: '/page1', visit_count: 10, visited_at: 5.days.ago) }
      let!(:most_visited2) { create(:page_visit, person: person, url: '/page2', visit_count: 8, visited_at: 4.days.ago) }
      let!(:most_visited3) { create(:page_visit, person: person, url: '/page3', visit_count: 6, visited_at: 3.days.ago) }
      let!(:recent1) { create(:page_visit, person: person, url: '/page4', visit_count: 2, visited_at: 1.hour.ago) }
      let!(:recent2) { create(:page_visit, person: person, url: '/page5', visit_count: 1, visited_at: 2.hours.ago) }
      let!(:recent3) { create(:page_visit, person: person, url: '/page6', visit_count: 1, visited_at: 3.hours.ago) }
      let!(:other_person_visit) { create(:page_visit, person: other_person, url: '/other', visit_count: 5) }

      it 'returns top 3 most visited first, then top 3 recent (deduped)' do
        result = controller.send(:recent_page_visits)
        
        # Should have 6 items total (3 most visited + 3 recent, no overlap)
        expect(result.length).to eq(6)
        
        # First 3 should be most visited (ordered by visit_count desc)
        expect(result[0..2]).to contain_exactly(most_visited1, most_visited2, most_visited3)
        expect(result[0]).to eq(most_visited1)
        expect(result[1]).to eq(most_visited2)
        expect(result[2]).to eq(most_visited3)
        
        # Last 3 should be recent (ordered by visited_at desc)
        expect(result[3..5]).to contain_exactly(recent1, recent2, recent3)
        expect(result[3]).to eq(recent1)
        expect(result[4]).to eq(recent2)
        expect(result[5]).to eq(recent3)
        
        # Should not include other person's visits
        expect(result).not_to include(other_person_visit)
      end

      context 'when there is overlap between most visited and recent' do
        let!(:overlap_visit) { create(:page_visit, person: person, url: '/overlap', visit_count: 7, visited_at: 30.minutes.ago) }

        it 'deduplicates - shows in most visited, not in recent' do
          result = controller.send(:recent_page_visits)
          
          # Should have overlap_visit in most visited section
          most_visited_section = result[0..2]
          expect(most_visited_section).to include(overlap_visit)
          
          # Should not have overlap_visit in recent section
          recent_section = result[3..-1]
          expect(recent_section).not_to include(overlap_visit)
        end
      end

      context 'when there are fewer than 3 most visited' do
        before do
          most_visited2.destroy
          most_visited3.destroy
        end

        it 'returns available most visited plus recent' do
          result = controller.send(:recent_page_visits)
          
          expect(result.length).to eq(4) # 1 most visited + 3 recent
          expect(result[0]).to eq(most_visited1)
          expect(result[1..3]).to contain_exactly(recent1, recent2, recent3)
        end
      end

      context 'when there are fewer than 3 recent' do
        before do
          recent2.destroy
          recent3.destroy
        end

        it 'returns most visited plus available recent' do
          result = controller.send(:recent_page_visits)
          
          expect(result.length).to eq(4) # 3 most visited + 1 recent
          expect(result[0..2]).to contain_exactly(most_visited1, most_visited2, most_visited3)
          expect(result[3]).to eq(recent1)
        end
      end

      context 'when all recent are also in most visited' do
        before do
          # Make the most visited pages also the most recent
          most_visited1.update(visited_at: 10.minutes.ago)
          most_visited2.update(visited_at: 20.minutes.ago)
          most_visited3.update(visited_at: 30.minutes.ago)
          recent1.destroy
          recent2.destroy
          recent3.destroy
        end

        it 'returns only most visited (no duplicates)' do
          result = controller.send(:recent_page_visits)
          
          expect(result.length).to eq(3)
          expect(result).to contain_exactly(most_visited1, most_visited2, most_visited3)
        end
      end
    end

    context 'when current_person is nil' do
      before do
        allow(controller).to receive(:current_person).and_return(nil)
      end

      it 'returns empty array' do
        expect(controller.send(:recent_page_visits)).to eq([])
      end
    end
  end
end 