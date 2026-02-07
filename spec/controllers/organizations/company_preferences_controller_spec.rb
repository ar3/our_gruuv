require 'rails_helper'

RSpec.describe Organizations::CompanyPreferencesController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { Organization.find_or_create_by!(name: 'Test Company') }
  
  before do
    teammate = CompanyTeammate.find_or_create_by!(person: person, organization: company)
    teammate.update!(can_customize_company: true)
    sign_in_as_teammate(person, company)
  end

  describe 'GET #edit' do
    it 'renders the edit template' do
      get :edit, params: { organization_id: company.to_param }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end

    it 'assigns company and preferences' do
      get :edit, params: { organization_id: company.to_param }
      expect(assigns(:company)).to eq(company)
      expect(assigns(:preferences)).to be_a(Hash)
    end

    it 'loads encourage_goal_and_observation preference with default value' do
      get :edit, params: { organization_id: company.to_param }
      expect(assigns(:preferences)['encourage_goal_and_observation']).to eq('true')
    end

    it 'loads existing encourage_goal_and_observation preference' do
      create(:company_label_preference, company: company, label_key: 'encourage_goal_and_observation', label_value: 'false')
      get :edit, params: { organization_id: company.to_param }
      expect(assigns(:preferences)['encourage_goal_and_observation']).to eq('false')
    end

    it 'loads kudos_point preference with default empty value' do
      get :edit, params: { organization_id: company.to_param }
      expect(assigns(:preferences)).to have_key('kudos_point')
      expect(assigns(:preferences)['kudos_point']).to eq('')
    end

    it 'loads existing kudos_point preference' do
      create(:company_label_preference, company: company, label_key: 'kudos_point', label_value: 'Star')
      get :edit, params: { organization_id: company.to_param }
      expect(assigns(:preferences)['kudos_point']).to eq('Star')
    end

    it 'requires customize_company permission' do
      teammate = CompanyTeammate.find_by(person: person, organization: company)
      teammate.update!(can_customize_company: false)
      get :edit, params: { organization_id: company.to_param }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'PATCH #update' do
    context 'with valid params' do
      it 'creates a new preference' do
        expect {
          patch :update, params: {
            organization_id: company.to_param,
            preferences: { prompt: 'Reflection' }
          }
        }.to change { company.reload.company_label_preferences.count }.by(1)
      end

      it 'updates an existing preference' do
        create(:company_label_preference, company: company, label_key: 'prompt', label_value: 'Question')
        patch :update, params: {
          organization_id: company.to_param,
          preferences: { prompt: 'Reflection' }
        }
        company.reload
        expect(company.company_label_preferences.find_by(label_key: 'prompt').label_value).to eq('Reflection')
      end

      it 'removes preference when value is blank' do
        create(:company_label_preference, company: company, label_key: 'prompt', label_value: 'Reflection')
        expect {
          patch :update, params: {
            organization_id: company.to_param,
            preferences: { prompt: '' }
          }
        }.to change { company.reload.company_label_preferences.count }.by(-1)
      end

      it 'redirects to edit page with success notice' do
        patch :update, params: {
          organization_id: company.to_param,
          preferences: { prompt: 'Reflection' }
        }
        expect(response).to redirect_to(edit_organization_company_preference_path(company))
        expect(flash[:notice]).to eq('Company preferences updated successfully.')
      end

      it 'creates encourage_goal_and_observation preference when checked' do
        expect {
          patch :update, params: {
            organization_id: company.to_param,
            preferences: { encourage_goal_and_observation: 'true' }
          }
        }.to change { company.reload.company_label_preferences.count }.by(1)
        
        preference = company.company_label_preferences.find_by(label_key: 'encourage_goal_and_observation')
        expect(preference.label_value).to eq('true')
      end

      it 'creates encourage_goal_and_observation preference when unchecked' do
        expect {
          patch :update, params: {
            organization_id: company.to_param,
            preferences: { encourage_goal_and_observation: 'false' }
          }
        }.to change { company.reload.company_label_preferences.count }.by(1)
        
        preference = company.company_label_preferences.find_by(label_key: 'encourage_goal_and_observation')
        expect(preference.label_value).to eq('false')
      end

      it 'updates existing encourage_goal_and_observation preference' do
        create(:company_label_preference, company: company, label_key: 'encourage_goal_and_observation', label_value: 'true')
        patch :update, params: {
          organization_id: company.to_param,
          preferences: { encourage_goal_and_observation: 'false' }
        }
        company.reload
        expect(company.company_label_preferences.find_by(label_key: 'encourage_goal_and_observation').label_value).to eq('false')
      end

      it 'handles checkbox value "1" as true' do
        patch :update, params: {
          organization_id: company.to_param,
          preferences: { encourage_goal_and_observation: '1' }
        }
        preference = company.reload.company_label_preferences.find_by(label_key: 'encourage_goal_and_observation')
        expect(preference.label_value).to eq('true')
      end

      it 'creates kudos_point preference' do
        expect {
          patch :update, params: {
            organization_id: company.to_param,
            preferences: { kudos_point: 'Star' }
          }
        }.to change { company.reload.company_label_preferences.count }.by(1)
        preference = company.company_label_preferences.find_by(label_key: 'kudos_point')
        expect(preference.label_value).to eq('Star')
      end

      it 'updates existing kudos_point preference' do
        create(:company_label_preference, company: company, label_key: 'kudos_point', label_value: 'Star')
        patch :update, params: {
          organization_id: company.to_param,
          preferences: { kudos_point: 'Highlight' }
        }
        company.reload
        expect(company.company_label_preferences.find_by(label_key: 'kudos_point').label_value).to eq('Highlight')
      end

      it 'removes kudos_point preference when value is blank' do
        create(:company_label_preference, company: company, label_key: 'kudos_point', label_value: 'Star')
        expect {
          patch :update, params: {
            organization_id: company.to_param,
            preferences: { kudos_point: '' }
          }
        }.to change { company.reload.company_label_preferences.count }.by(-1)
      end
    end

    it 'requires customize_company permission' do
      teammate = CompanyTeammate.find_by(person: person, organization: company)
      teammate.update!(can_customize_company: false)
      patch :update, params: {
        organization_id: company.to_param,
        preferences: { prompt: 'Reflection' }
      }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end
  end
end
