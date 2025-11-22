require 'rails_helper'

RSpec.describe 'Prompt Templates', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, person: person, organization: organization, can_manage_prompts: true) }

  before do
    teammate # Ensure teammate exists before signing in
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/prompt_templates' do
    let!(:template1) { create(:prompt_template, company: organization, title: 'Template 1') }
    let!(:template2) { create(:prompt_template, company: organization, title: 'Template 2') }

    it 'returns http success' do
      get organization_prompt_templates_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'renders the index template' do
      get organization_prompt_templates_path(organization)
      expect(response).to render_template(:index)
    end
  end

  describe 'GET /organizations/:organization_id/prompt_templates/new' do
    it 'returns http success' do
      get new_organization_prompt_template_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'renders the new template' do
      get new_organization_prompt_template_path(organization)
      expect(response).to render_template(:new)
    end
  end

  describe 'POST /organizations/:organization_id/prompt_templates' do
    context 'with valid params' do
      it 'creates a new prompt template' do
        expect {
          post organization_prompt_templates_path(organization), params: {
            prompt_template: {
              title: 'New Template',
              description: 'A new template',
              available_at: Date.current
            }
          }
        }.to change { PromptTemplate.count }.by(1)
      end

      it 'redirects to the index' do
        post organization_prompt_templates_path(organization), params: {
          prompt_template: {
            title: 'New Template',
            description: 'A new template'
          }
        }
        expect(response).to redirect_to(organization_prompt_templates_path(organization))
      end
    end

    context 'with invalid params' do
      it 'renders new template with errors' do
        post organization_prompt_templates_path(organization), params: {
          prompt_template: {
            title: '',
            description: 'A new template'
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET /organizations/:organization_id/prompt_templates/:id/edit' do
    let(:template) { create(:prompt_template, company: organization) }

    it 'returns http success' do
      get edit_organization_prompt_template_path(organization, template)
      expect(response).to have_http_status(:success)
    end

    it 'renders the edit template' do
      get edit_organization_prompt_template_path(organization, template)
      expect(response).to render_template(:edit)
    end
  end

  describe 'PATCH /organizations/:organization_id/prompt_templates/:id' do
    let(:template) { create(:prompt_template, company: organization, title: 'Original Title') }

    context 'with valid params' do
      it 'updates the template' do
        patch organization_prompt_template_path(organization, template), params: {
          prompt_template: {
            title: 'Updated Title'
          }
        }
        template.reload
        expect(template.title).to eq('Updated Title')
      end

      it 'redirects to the index' do
        patch organization_prompt_template_path(organization, template), params: {
          prompt_template: {
            title: 'Updated Title'
          }
        }
        expect(response).to redirect_to(organization_prompt_templates_path(organization))
      end
    end

    context 'with invalid params' do
      it 'renders edit template with errors' do
        patch organization_prompt_template_path(organization, template), params: {
          prompt_template: {
            title: ''
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE /organizations/:organization_id/prompt_templates/:id' do
    let!(:template) { create(:prompt_template, company: organization) }

    it 'deletes the template' do
      expect {
        delete organization_prompt_template_path(organization, template)
      }.to change { PromptTemplate.count }.by(-1)
    end

    it 'redirects to the index' do
      delete organization_prompt_template_path(organization, template)
      expect(response).to redirect_to(organization_prompt_templates_path(organization))
    end
  end

  describe 'authorization' do
    let(:unauthorized_person) { create(:person) }
    let(:unauthorized_teammate) { create(:teammate, person: unauthorized_person, organization: organization, can_manage_prompts: false) }
    let(:template) { create(:prompt_template, company: organization) }

    before do
      sign_in_as_teammate_for_request(unauthorized_person, organization)
    end

    it 'prevents access to new' do
      get new_organization_prompt_template_path(organization)
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to create' do
      post organization_prompt_templates_path(organization), params: {
        prompt_template: { title: 'New Template' }
      }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to edit' do
      get edit_organization_prompt_template_path(organization, template)
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to update' do
      patch organization_prompt_template_path(organization, template), params: {
        prompt_template: { title: 'Updated Title' }
      }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to destroy' do
      delete organization_prompt_template_path(organization, template)
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end
  end
end

