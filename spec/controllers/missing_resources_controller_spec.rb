require 'rails_helper'

RSpec.describe MissingResourcesController, type: :controller do
  describe 'GET #show' do
    let(:path) { '/our/explore/choose_roles' }

    before do
      allow(TrackMissingResourceJob).to receive(:perform_and_get_result)
    end

    context 'when path is provided' do
      it 'renders the show template' do
        get :show, params: { path: path }
        expect(response).to have_http_status(:not_found)
        expect(response).to render_template(:show)
      end

      it 'assigns the path' do
        get :show, params: { path: path }
        expect(assigns(:path)).to eq(path)
      end

      it 'generates suggestions' do
        get :show, params: { path: path }
        expect(assigns(:suggestions)).to be_an(Array)
      end

      it 'tracks the missing resource' do
        person = create(:person)
        allow(controller).to receive(:current_person).and_return(person)
        
        get :show, params: { path: path }
        
        expect(TrackMissingResourceJob).to have_received(:perform_and_get_result).with(
          path,
          person.id,
          anything,
          anything,
          anything,
          anything,
          anything
        )
      end
    end

    context 'when path is not provided' do
      it 'uses request.path' do
        # Don't pass path param, let controller use request.path
        get :show, params: { path: '/some/path' }
        expect(assigns(:path)).to eq('/some/path')
      end
    end

    context 'when user is logged in with organization' do
      let(:person) { create(:person) }
      let(:organization) { create(:organization) }
      let(:teammate) { create(:company_teammate, person: person, organization: organization) }

      before do
        allow(controller).to receive(:current_person).and_return(person)
        allow(controller).to receive(:current_organization).and_return(organization)
        session[:current_company_teammate_id] = teammate.id
      end

      it 'includes organization-specific suggestions' do
        get :show, params: { path: '/employees' }
        suggestions = assigns(:suggestions)
        expect(suggestions.any? { |s| s[:title] == 'Employees' }).to be true
      end
    end

    context 'when user is not logged in' do
      before do
        allow(controller).to receive(:current_person).and_return(nil)
        allow(controller).to receive(:current_organization).and_return(nil)
      end

      it 'tracks with nil person_id' do
        get :show, params: { path: path }
        
        expect(TrackMissingResourceJob).to have_received(:perform_and_get_result).with(
          path,
          nil,
          anything,
          anything,
          anything,
          anything,
          anything
        )
      end

      it 'includes home page suggestion' do
        get :show, params: { path: path }
        suggestions = assigns(:suggestions)
        expect(suggestions.any? { |s| s[:title] == 'Home' }).to be true
      end
    end

    context 'when tracking fails' do
      before do
        allow(TrackMissingResourceJob).to receive(:perform_and_get_result).and_raise(StandardError.new('Tracking error'))
        allow(Rails.logger).to receive(:error)
      end

      it 'still renders the page' do
        expect {
          get :show, params: { path: path }
        }.not_to raise_error
        
        expect(response).to have_http_status(:not_found)
        expect(response).to render_template(:show)
      end
    end

    context 'JSON format' do
      it 'returns JSON response' do
        get :show, params: { path: path }, format: :json
        expect(response).to have_http_status(:not_found)
        
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Not found')
        expect(json['path']).to eq(path)
        expect(json['suggestions']).to be_an(Array)
      end
    end
  end
end

