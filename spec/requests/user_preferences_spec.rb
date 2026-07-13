require 'rails_helper'

RSpec.describe 'User Preferences', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:user_preference) { UserPreference.for_person(person) }
  
  before do
    sign_in_as_teammate_for_request(person, organization)
  end
  
  describe 'PATCH /user_preferences/vertical_nav' do
    context 'updating open state' do
      it 'updates open state to true' do
        patch vertical_nav_user_preferences_path, params: { open: 'true' }, headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:success)
        expect(user_preference.reload.vertical_nav_open?).to eq(true)
      end
      
      it 'updates open state to false' do
        user_preference.update_preference(:vertical_nav_open, true)
        
        patch vertical_nav_user_preferences_path, params: { open: 'false' }, headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:success)
        expect(user_preference.reload.vertical_nav_open?).to eq(false)
      end

      it 'does not change mode when opening nav temporarily' do
        user_preference.update_preference(:vertical_nav_mode, 'closed_unless_opened')
        user_preference.update_preference(:vertical_nav_open, false)
        user_preference.update_preference(:vertical_nav_locked, false)

        patch vertical_nav_user_preferences_path, params: { open: 'true' }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        user_preference.reload
        expect(user_preference.vertical_nav_open?).to eq(true)
        expect(user_preference.vertical_nav_mode).to eq('closed_unless_opened')
      end

      it 'does not change mode when open update includes unchanged locked value' do
        user_preference.update_preference(:vertical_nav_mode, 'closed_unless_opened')
        user_preference.update_preference(:vertical_nav_open, false)
        user_preference.update_preference(:vertical_nav_locked, false)

        patch vertical_nav_user_preferences_path, params: { open: 'true', locked: 'false' }, headers: { 'Accept' => 'application/json' }

        expect(response).to have_http_status(:success)
        user_preference.reload
        expect(user_preference.vertical_nav_open?).to eq(true)
        expect(user_preference.vertical_nav_mode).to eq('closed_unless_opened')
      end
    end
    
    context 'updating locked state' do
      it 'updates locked state to true' do
        patch vertical_nav_user_preferences_path, params: { locked: 'true' }, headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:success)
        expect(user_preference.reload.vertical_nav_locked?).to eq(true)
      end
      
      it 'updates locked state to false' do
        user_preference.update_preference(:vertical_nav_locked, true)
        
        patch vertical_nav_user_preferences_path, params: { locked: 'false' }, headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:success)
        expect(user_preference.reload.vertical_nav_locked?).to eq(false)
      end
      
      it 'automatically sets open to true when locking' do
        # Start with nav closed
        user_preference.update_preference(:vertical_nav_open, false)
        user_preference.update_preference(:vertical_nav_locked, false)
        
        # Lock the navigation
        patch vertical_nav_user_preferences_path, params: { locked: 'true' }, headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:success)
        user_preference.reload
        expect(user_preference.vertical_nav_locked?).to eq(true)
        expect(user_preference.vertical_nav_open?).to eq(true)
      end
      
      it 'automatically sets open to true when locking via HTML request' do
        # Start with nav closed
        user_preference.update_preference(:vertical_nav_open, false)
        user_preference.update_preference(:vertical_nav_locked, false)
        
        # Lock the navigation via HTML (form POST)
        patch vertical_nav_user_preferences_path, params: { locked: 'true', open: 'true' }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Navigation preference updated')
        user_preference.reload
        expect(user_preference.vertical_nav_locked?).to eq(true)
        expect(user_preference.vertical_nav_open?).to eq(true)
      end
      
      it 'persists locked state with open=true across page loads' do
        # Lock the navigation
        patch vertical_nav_user_preferences_path, params: { locked: 'true' }
        
        # Simulate a new page load
        get dashboard_organization_path(organization)
        
        # Both locked and open should be true
        user_preference.reload
        expect(user_preference.vertical_nav_locked?).to eq(true)
        expect(user_preference.vertical_nav_open?).to eq(true)
      end
    end
    
    context 'updating both states' do
      it 'updates both open and locked states' do
        patch vertical_nav_user_preferences_path, params: { open: 'true', locked: 'true' }, headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:success)
        expect(user_preference.reload.vertical_nav_open?).to eq(true)
        expect(user_preference.reload.vertical_nav_locked?).to eq(true)
      end
    end
    
    context 'JSON response' do
      it 'returns current state in JSON' do
        user_preference.update_preference(:vertical_nav_open, true)
        user_preference.update_preference(:vertical_nav_locked, false)
        
        patch vertical_nav_user_preferences_path, params: { open: 'true' }, headers: { 'Accept' => 'application/json' }
        
        json = JSON.parse(response.body)
        expect(json['open']).to eq(true)
        expect(json['locked']).to eq(false)
        expect(json['mode']).to eq('closed_unless_opened')
      end
    end
    
    context 'when not authenticated' do
      before do
        sign_out_teammate_for_request
      end
      
      it 'redirects to login' do
        patch vertical_nav_user_preferences_path, params: { open: 'true' }
        
        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe 'PATCH /user_preferences/vertical_nav_mode' do
    it 'updates mode to locked_open and syncs open/locked' do
      patch vertical_nav_mode_user_preferences_path, params: { mode: 'locked_open' }, headers: { 'Accept' => 'application/json' }

      expect(response).to have_http_status(:success)
      user_preference.reload
      expect(user_preference.vertical_nav_mode).to eq('locked_open')
      expect(user_preference.vertical_nav_locked?).to eq(true)
      expect(user_preference.vertical_nav_open?).to eq(true)
    end

    it 'rejects invalid mode' do
      patch vertical_nav_mode_user_preferences_path, params: { mode: 'not_real' }
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to match(/Invalid vertical navigation behavior/)
    end
  end
  
  describe 'authenticated layout' do
    it 'uses vertical navigation chrome' do
      get dashboard_organization_path(organization)
      follow_redirect! if response.redirect?
      
      expect(response).to have_http_status(:success)
      expect(response.body).to include('vertical-nav-top-bar')
      expect(response.body).to include('vertical-nav')
    end
  end

  describe 'vertical nav state on redirects' do
    it 'closes the vertical nav after redirect when mode is closed_unless_opened' do
      user_preference.update_preference(:vertical_nav_open, true)
      user_preference.update_preference(:vertical_nav_locked, false)
      user_preference.update_preference(:vertical_nav_mode, 'closed_unless_opened')

      get dashboard_organization_path(organization)

      expect(response).to be_redirect
      expect(user_preference.reload.vertical_nav_open?).to eq(false)
    end

    it 'keeps the vertical nav open after redirect when locked' do
      user_preference.update_preference(:vertical_nav_open, true)
      user_preference.update_preference(:vertical_nav_locked, true)
      user_preference.update_preference(:vertical_nav_mode, 'locked_open')

      get dashboard_organization_path(organization)

      expect(response).to be_redirect
      user_preference.reload
      expect(user_preference.vertical_nav_open?).to eq(true)
    end
  end
end
