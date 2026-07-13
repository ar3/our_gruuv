require 'rails_helper'

RSpec.describe UserPreferencesController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization) }
  let(:teammate) { create(:teammate, person: person, organization: organization) }
  let(:user_preference) { UserPreference.for_person(person) }
  
  before do
    sign_in_as_teammate(person, organization)
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
      expect(json['mode']).to eq('closed_unless_opened')
    end

    it 'does not change mode on open-only updates' do
      user_preference.update_preference(:vertical_nav_mode, 'closed_unless_opened')
      user_preference.update_preference(:vertical_nav_open, false)
      user_preference.update_preference(:vertical_nav_locked, false)

      patch :update_vertical_nav, params: { open: 'true' }, format: :json

      expect(user_preference.reload.vertical_nav_open?).to eq(true)
      expect(user_preference.vertical_nav_mode).to eq('closed_unless_opened')
    end

    it 'does not change mode when locked is submitted unchanged' do
      user_preference.update_preference(:vertical_nav_mode, 'closed_unless_opened')
      user_preference.update_preference(:vertical_nav_open, false)
      user_preference.update_preference(:vertical_nav_locked, false)

      patch :update_vertical_nav, params: { open: 'true', locked: 'false' }, format: :json

      expect(user_preference.reload.vertical_nav_open?).to eq(true)
      expect(user_preference.vertical_nav_mode).to eq('closed_unless_opened')
    end

    context 'when not authenticated' do
      before do
        session[:current_company_teammate_id] = nil
      end

      it 'redirects to login' do
        patch :update_vertical_nav, params: { open: 'true' }

        expect(response).to redirect_to(login_path)
      end
    end
  end

  describe 'PATCH #update_vertical_nav_mode' do
    it 'updates nav mode and syncs open/locked state' do
      patch :update_vertical_nav_mode, params: { mode: 'closed_unless_opened' }, format: :json

      expect(user_preference.reload.vertical_nav_mode).to eq('closed_unless_opened')
      expect(user_preference.vertical_nav_locked?).to eq(false)
      expect(user_preference.vertical_nav_open?).to eq(false)
    end
  end
  
  describe 'authorization' do
    let(:other_person) { create(:person) }
    let(:other_teammate) { create(:teammate, person: other_person, organization: organization) }
    
    it 'prevents updating other user preferences' do
      other_pundit_user = OpenStruct.new(
        user: other_teammate,
        impersonating_teammate: nil
      )
      
      policy = UserPreferencePolicy.new(other_pundit_user, user_preference)
      
      expect(policy.update_vertical_nav?).to eq(false)
    end
    
    it 'allows updating own preferences' do
      expect {
        patch :update_vertical_nav, params: { open: 'true' }
      }.not_to raise_error
      
      expect(response).to have_http_status(:redirect)
    end
  end
end
