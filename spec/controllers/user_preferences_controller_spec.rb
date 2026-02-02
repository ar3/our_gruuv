require 'rails_helper'

RSpec.describe UserPreferencesController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:user_preference) { UserPreference.for_person(person) }
  
  before do
    sign_in_as_teammate(person, organization)
  end
  
  describe 'PATCH #update_layout' do
    context 'with valid layout' do
      it 'updates the layout preference' do
        patch :update_layout, params: { layout: 'vertical' }
        
        expect(user_preference.reload.layout).to eq('vertical')
      end
      
      it 'redirects back with notice' do
        patch :update_layout, params: { layout: 'vertical' }
        
        expect(response).to redirect_to(root_path)
        expect(flash[:notice]).to eq('Layout preference updated')
      end
      
      it 'returns JSON when requested' do
        patch :update_layout, params: { layout: 'vertical' }, format: :json
        
        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json['layout']).to eq('vertical')
      end
    end
    
    context 'with invalid layout' do
      it 'returns error for invalid layout' do
        patch :update_layout, params: { layout: 'invalid' }, format: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json['error']).to eq('Invalid layout')
      end
    end
    
    context 'when not authenticated' do
      before do
        session[:current_company_teammate_id] = nil
      end
      
      it 'redirects to login' do
        patch :update_layout, params: { layout: 'vertical' }
        
        expect(response).to redirect_to(login_path)
      end
    end
  end
  
  describe 'PATCH #update_vertical_nav' do
    it 'updates open state' do
      patch :update_vertical_nav, params: { open: 'true' }, format: :json
      
      expect(user_preference.reload.vertical_nav_open?).to eq(true)
    end
    
    it 'updates locked state' do
      patch :update_vertical_nav, params: { locked: 'true' }, format: :json
      
      expect(user_preference.reload.vertical_nav_locked?).to eq(true)
    end
    
    it 'updates both states' do
      patch :update_vertical_nav, params: { open: 'true', locked: 'true' }, format: :json
      
      expect(user_preference.reload.vertical_nav_open?).to eq(true)
      expect(user_preference.reload.vertical_nav_locked?).to eq(true)
    end
    
    it 'returns JSON with current state' do
      patch :update_vertical_nav, params: { open: 'true' }, format: :json
      
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json['open']).to eq(true)
      expect(json['locked']).to eq(false)
    end
  end
  
  describe 'authorization' do
    let(:other_person) { create(:person) }
    let(:other_teammate) { create(:teammate, person: other_person, organization: organization) }
    let(:other_preference) { UserPreference.for_person(other_person) }
    
    it 'prevents updating other user preferences' do
      # Create pundit_user for the other person
      other_pundit_user = OpenStruct.new(
        user: other_teammate,
        impersonating_teammate: nil
      )
      
      # The policy should prevent the current user from updating another person's preferences
      policy = UserPreferencePolicy.new(other_pundit_user, user_preference)
      
      expect(policy.update_layout?).to eq(false)
    end
    
    it 'allows updating own preferences' do
      # Current user should be able to update their own preferences
      expect {
        patch :update_layout, params: { layout: 'vertical' }
      }.not_to raise_error
      
      expect(response).to have_http_status(:redirect)
    end
  end
end

