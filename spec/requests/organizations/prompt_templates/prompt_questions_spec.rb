require 'rails_helper'

RSpec.describe 'Prompt Questions', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company) }
  let(:teammate) { create(:teammate, person: person, organization: organization, can_manage_prompts: true) }
  let(:prompt_template) { create(:prompt_template, company: organization) }

  before do
    teammate # Ensure teammate exists before signing in
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/prompt_templates/:prompt_template_id/prompt_questions/new' do
    it 'returns http success' do
      get new_organization_prompt_template_prompt_question_path(organization, prompt_template)
      expect(response).to have_http_status(:success)
    end

    it 'renders the new template' do
      get new_organization_prompt_template_prompt_question_path(organization, prompt_template)
      expect(response).to render_template(:new)
    end
  end

  describe 'POST /organizations/:organization_id/prompt_templates/:prompt_template_id/prompt_questions' do
    context 'with valid params' do
      it 'creates a new prompt question' do
        expect {
          post organization_prompt_template_prompt_questions_path(organization, prompt_template), params: {
            prompt_question: {
              label: 'What are your goals?',
              placeholder_text: 'Enter your goals here',
              helper_text: 'Think about what you want to accomplish',
              position: 1
            }
          }
        }.to change { PromptQuestion.count }.by(1)
      end

      it 'redirects to the edit question page' do
        post organization_prompt_template_prompt_questions_path(organization, prompt_template), params: {
          prompt_question: {
            label: 'What are your goals?',
            position: 1
          }
        }
        question = PromptQuestion.last
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include(edit_organization_prompt_template_prompt_question_path(organization, prompt_template, question))
      end
    end

    context 'with invalid params' do
      it 'renders new template with errors' do
        post organization_prompt_template_prompt_questions_path(organization, prompt_template), params: {
          prompt_question: {
            label: '',
            position: 1
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'GET /organizations/:organization_id/prompt_templates/:prompt_template_id/prompt_questions/:id/edit' do
    let(:question) { create(:prompt_question, prompt_template: prompt_template) }

    it 'returns http success' do
      get edit_organization_prompt_template_prompt_question_path(organization, prompt_template, question)
      expect(response).to have_http_status(:success)
    end

    it 'renders the edit template' do
      get edit_organization_prompt_template_prompt_question_path(organization, prompt_template, question)
      expect(response).to render_template(:edit)
    end
  end

  describe 'PATCH /organizations/:organization_id/prompt_templates/:prompt_template_id/prompt_questions/:id' do
    let(:question) { create(:prompt_question, prompt_template: prompt_template, label: 'Original Label') }

    context 'with valid params' do
      it 'updates the question' do
        patch organization_prompt_template_prompt_question_path(organization, prompt_template, question), params: {
          prompt_question: {
            label: 'Updated Label'
          }
        }
        question.reload
        expect(question.label).to eq('Updated Label')
      end

      it 'redirects to the template edit page' do
        patch organization_prompt_template_prompt_question_path(organization, prompt_template, question), params: {
          prompt_question: {
            label: 'Updated Label'
          }
        }
        expect(response).to redirect_to(edit_organization_prompt_template_path(organization, prompt_template))
      end
    end

    context 'with invalid params' do
      it 'renders edit template with errors' do
        patch organization_prompt_template_prompt_question_path(organization, prompt_template, question), params: {
          prompt_question: {
            label: ''
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE /organizations/:organization_id/prompt_templates/:prompt_template_id/prompt_questions/:id' do
    let!(:question) { create(:prompt_question, prompt_template: prompt_template) }

    it 'deletes the question' do
      expect {
        delete organization_prompt_template_prompt_question_path(organization, prompt_template, question)
      }.to change { PromptQuestion.count }.by(-1)
    end

    it 'redirects to the template edit page' do
      delete organization_prompt_template_prompt_question_path(organization, prompt_template, question)
      expect(response).to redirect_to(edit_organization_prompt_template_path(organization, prompt_template))
    end
  end

  describe 'authorization' do
    let(:unauthorized_person) { create(:person) }
    let(:unauthorized_teammate) { create(:teammate, person: unauthorized_person, organization: organization, can_manage_prompts: false) }
    let(:question) { create(:prompt_question, prompt_template: prompt_template) }

    before do
      unauthorized_teammate # Ensure teammate exists
      sign_in_as_teammate_for_request(unauthorized_person, organization)
    end

    it 'prevents access to new' do
      get new_organization_prompt_template_prompt_question_path(organization, prompt_template)
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to create' do
      post organization_prompt_template_prompt_questions_path(organization, prompt_template), params: {
        prompt_question: { label: 'New Question', position: 1 }
      }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to edit' do
      get edit_organization_prompt_template_prompt_question_path(organization, prompt_template, question)
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to update' do
      patch organization_prompt_template_prompt_question_path(organization, prompt_template, question), params: {
        prompt_question: { label: 'Updated Label' }
      }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to destroy' do
      delete organization_prompt_template_prompt_question_path(organization, prompt_template, question)
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end
  end
end

