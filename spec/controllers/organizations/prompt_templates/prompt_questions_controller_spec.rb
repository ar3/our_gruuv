require 'rails_helper'

RSpec.describe Organizations::PromptTemplates::PromptQuestionsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: 'Test Company') }
  let(:template) { create(:prompt_template, company: organization) }

  before do
    # Create a teammate for the person in the organization with prompts management permissions
    create(:teammate, person: person, organization: organization, can_manage_prompts: true)
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #new' do
    it 'renders the new template with overlay layout' do
      get :new, params: {
        organization_id: organization.id,
        prompt_template_id: template.id
      }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'assigns a new prompt question' do
      get :new, params: {
        organization_id: organization.id,
        prompt_template_id: template.id
      }
      expect(assigns(:prompt_question)).to be_a_new(PromptQuestion)
      expect(assigns(:prompt_question).prompt_template).to eq(template)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new prompt question' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            prompt_template_id: template.id,
            prompt_question: {
              label: 'What are your goals?',
              placeholder_text: 'Enter your goals',
              helper_text: 'Think about what you want to accomplish',
              position: 1
            }
          }
        }.to change { PromptQuestion.count }.by(1)
      end

      it 'redirects to edit question page' do
        post :create, params: {
          organization_id: organization.id,
          prompt_template_id: template.id,
          prompt_question: {
            label: 'What are your goals?',
            position: 1
          }
        }
        question = PromptQuestion.last
        # Note: The redirect includes query params, so we check the path matches
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include(edit_organization_prompt_template_prompt_question_path(organization, template, question))
      end
    end

    context 'with invalid params' do
      it 'renders new template with errors' do
        post :create, params: {
          organization_id: organization.id,
          prompt_template_id: template.id,
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

  describe 'GET #edit' do
    let(:question) { create(:prompt_question, prompt_template: template) }

    it 'renders the edit template with overlay layout' do
      get :edit, params: {
        organization_id: organization.id,
        prompt_template_id: template.id,
        id: question.id
      }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'assigns the prompt question and versions' do
      get :edit, params: {
        organization_id: organization.id,
        prompt_template_id: template.id,
        id: question.id
      }
      expect(assigns(:prompt_question)).to eq(question)
      expect(assigns(:versions)).to eq(question.versions.order(created_at: :desc))
    end
  end

  describe 'PATCH #update' do
    let(:question) { create(:prompt_question, prompt_template: template, label: 'Original Label') }

    context 'with valid params' do
      it 'updates the question' do
        patch :update, params: {
          organization_id: organization.id,
          prompt_template_id: template.id,
          id: question.id,
          prompt_question: {
            label: 'Updated Label'
          }
        }
        question.reload
        expect(question.label).to eq('Updated Label')
      end

      it 'redirects to edit template' do
        patch :update, params: {
          organization_id: organization.id,
          prompt_template_id: template.id,
          id: question.id,
          prompt_question: {
            label: 'Updated Label'
          }
        }
        expect(response).to redirect_to(edit_organization_prompt_template_path(organization, template))
      end
    end

    context 'with invalid params' do
      it 'renders edit template with errors' do
        patch :update, params: {
          organization_id: organization.id,
          prompt_template_id: template.id,
          id: question.id,
          prompt_question: {
            label: ''
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:question) { create(:prompt_question, prompt_template: template) }

    it 'deletes the question' do
      expect {
        delete :destroy, params: {
          organization_id: organization.id,
          prompt_template_id: template.id,
          id: question.id
        }
      }.to change { PromptQuestion.count }.by(-1)
    end

    it 'redirects to edit template' do
      delete :destroy, params: {
        organization_id: organization.id,
        prompt_template_id: template.id,
        id: question.id
      }
      expect(response).to redirect_to(edit_organization_prompt_template_path(organization, template))
    end
  end
end

