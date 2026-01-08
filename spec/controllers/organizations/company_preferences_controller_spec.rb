require 'rails_helper'

RSpec.describe Organizations::CompanyPreferencesController, type: :controller do
  let(:person) { create(:person) }
  let(:company) { Company.find_or_create_by!(name: 'Test Company', type: 'Company') }
  
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

    it 'requires customize_company permission' do
      teammate = CompanyTeammate.find_by(person: person, organization: company)
      teammate.update!(can_customize_company: false)
      # Reload to ensure the change is picked up
      teammate.reload
      # Ensure person is not an OG admin
      allow(person).to receive(:og_admin?).and_return(false)
      expect {
        get :edit, params: { organization_id: company.to_param }
      }.to raise_error(Pundit::NotAuthorizedError)
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
    end

    it 'requires customize_company permission' do
      teammate = CompanyTeammate.find_by(person: person, organization: company)
      teammate.update!(can_customize_company: false)
      # Reload to ensure the change is picked up
      teammate.reload
      # Ensure person is not an OG admin
      allow(person).to receive(:og_admin?).and_return(false)
      expect {
        patch :update, params: {
          organization_id: company.to_param,
          preferences: { prompt: 'Reflection' }
        }
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
