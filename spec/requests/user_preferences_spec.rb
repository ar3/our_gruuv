require 'rails_helper'

RSpec.describe 'User Preferences', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:user_preference) { UserPreference.for_person(person) }
  
  before do
    sign_in_as_teammate_for_request(person, organization)
  end
  
  describe 'PATCH /user_preferences/layout' do
    context 'with valid layout' do
      it 'updates the layout preference' do
        expect {
          patch layout_user_preferences_path, params: { layout: 'horizontal' }
        }.to change { user_preference.reload.layout }.from('vertical').to('horizontal')
      end
      
      it 'redirects back with notice' do
        patch layout_user_preferences_path, params: { layout: 'vertical' }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Layout preference updated')
      end
      
      it 'returns JSON when requested' do
        patch layout_user_preferences_path, params: { layout: 'vertical' }, headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['layout']).to eq('vertical')
      end
      
      it 'persists the preference across requests' do
        patch layout_user_preferences_path, params: { layout: 'vertical' }
        
        # Verify preference was saved
        expect(user_preference.reload.layout).to eq('vertical')
        
        # Simulate a new request - preference should still be vertical
        get dashboard_organization_path(organization)
        
        # Preference should persist
        expect(UserPreference.for_person(person).layout).to eq('vertical')
      end
    end
    
    context 'with invalid layout' do
      it 'returns error for invalid layout' do
        patch layout_user_preferences_path, params: { layout: 'invalid' }, headers: { 'Accept' => 'application/json' }
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Invalid layout')
      end
      
      it 'does not update preference with invalid layout' do
        original_layout = user_preference.layout
        
        patch layout_user_preferences_path, params: { layout: 'invalid' }, headers: { 'Accept' => 'application/json' }
        
        expect(user_preference.reload.layout).to eq(original_layout)
      end
    end
    
    context 'when not authenticated' do
      before do
        sign_out_teammate_for_request
      end
      
      it 'redirects to login' do
        patch layout_user_preferences_path, params: { layout: 'vertical' }
        
        expect(response).to redirect_to(login_path)
      end
    end
    
    context 'authorization' do
      let(:other_person) { create(:person) }
      let(:other_organization) { create(:organization) }
      let(:other_preference) { UserPreference.for_person(other_person) }
      
      before do
        sign_in_as_teammate_for_request(other_person, other_organization)
      end
      
      it 'allows users to update their own preferences' do
        patch layout_user_preferences_path, params: { layout: 'vertical' }
        
        expect(response).to have_http_status(:redirect)
        expect(other_preference.reload.layout).to eq('vertical')
      end
      
      it 'does not allow users to update other users preferences' do
        # This is tested via Pundit policy - the controller should prevent this
        # The preference should only update for the current user
        original_layout = user_preference.layout
        
        patch layout_user_preferences_path, params: { layout: 'vertical' }
        
        # Other person's preference should not change
        expect(user_preference.reload.layout).to eq(original_layout)
      end
    end
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
  
  describe 'integration with layout selection' do
    it 'uses vertical layout when preference is set to vertical' do
      user_preference.update_preference(:layout, 'vertical')
      
      get dashboard_organization_path(organization)
      follow_redirect! if response.redirect?
      
      expect(response).to have_http_status(:success)
      # Verify preference is actually set
      expect(UserPreference.for_person(person).layout).to eq('vertical')
      # Verify vertical layout is used by checking for vertical nav elements
      expect(response.body).to include('vertical-nav-top-bar')
      expect(response.body).to include('vertical-nav')
    end
    
    it 'uses horizontal layout when preference is set to horizontal' do
      user_preference.update_preference(:layout, 'horizontal')
      
      get dashboard_organization_path(organization)
      follow_redirect! if response.redirect?
      
      expect(response).to have_http_status(:success)
      # Horizontal layout should have navbar, not vertical nav
      expect(response.body).to include('navbar navbar-expand-lg')
      expect(response.body).not_to include('vertical-nav-top-bar')
    end
    
    it 'defaults to vertical layout when no preference exists' do
      user_preference.destroy
      
      get dashboard_organization_path(organization)
      follow_redirect! if response.redirect?
      
      expect(response).to have_http_status(:success)
      # Should default to vertical - verify by checking for vertical nav elements
      expect(response.body).to include('vertical-nav-top-bar')
      expect(response.body).to include('vertical-nav')
    end
  end
end

