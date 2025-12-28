require 'rails_helper'

RSpec.describe Organizations::PromptTemplatesController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }

  before do
    # Create a teammate for the person in the organization with prompts management permissions
    create(:teammate, person: person, organization: organization, can_manage_prompts: true)
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #index' do
    let!(:template1) { create(:prompt_template, company: organization, title: 'Template 1') }
    let!(:template2) { create(:prompt_template, company: organization, title: 'Template 2') }

    it 'renders the index template' do
      get :index, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end

    it 'assigns prompt templates' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:prompt_templates)).to include(template1, template2)
    end
  end

  describe 'GET #new' do
    it 'renders the new template' do
      get :new, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
    end

    it 'assigns a new prompt template' do
      get :new, params: { organization_id: organization.id }
      expect(assigns(:prompt_template)).to be_a_new(PromptTemplate)
      expect(assigns(:prompt_template).company_id).to eq(organization.id)
    end
  end

  describe 'POST #create' do
    context 'with valid params' do
      it 'creates a new prompt template' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            prompt_template: {
              title: 'New Template',
              description: 'A new template',
              available_at: Date.current,
              is_primary: false
            }
          }
        }.to change { PromptTemplate.count }.by(1)
      end

      it 'redirects to the index' do
        post :create, params: {
          organization_id: organization.id,
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
        post :create, params: {
          organization_id: organization.id,
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

  describe 'GET #edit' do
    let(:template) { create(:prompt_template, company: organization) }

    it 'renders the edit template' do
      get :edit, params: { organization_id: organization.id, id: template.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end

    it 'assigns the prompt template' do
      get :edit, params: { organization_id: organization.id, id: template.id }
      expect(assigns(:prompt_template)).to eq(template)
    end

    it 'assigns prompt_questions ordered by position' do
      question1 = create(:prompt_question, prompt_template: template, position: 2)
      question2 = create(:prompt_question, prompt_template: template, position: 1)
      question3 = create(:prompt_question, prompt_template: template, position: 3)

      get :edit, params: { organization_id: organization.id, id: template.id }
      expect(assigns(:prompt_questions)).to eq([question2, question1, question3])
    end
  end

  describe 'PATCH #update' do
    let(:template) { create(:prompt_template, company: organization, title: 'Original Title') }

    context 'with valid params' do
      it 'updates the template' do
        patch :update, params: {
          organization_id: organization.id,
          id: template.id,
          prompt_template: {
            title: 'Updated Title'
          }
        }
        template.reload
        expect(template.title).to eq('Updated Title')
      end

      it 'redirects to the index' do
        patch :update, params: {
          organization_id: organization.id,
          id: template.id,
          prompt_template: {
            title: 'Updated Title'
          }
        }
        expect(response).to redirect_to(organization_prompt_templates_path(organization))
      end
    end

    context 'with invalid params' do
      it 'renders edit template with errors' do
        patch :update, params: {
          organization_id: organization.id,
          id: template.id,
          prompt_template: {
            title: ''
          }
        }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'DELETE #destroy' do
    let!(:template) { create(:prompt_template, company: organization) }

    it 'deletes the template' do
      expect {
        delete :destroy, params: { organization_id: organization.id, id: template.id }
      }.to change { PromptTemplate.count }.by(-1)
    end

    it 'redirects to the index' do
      delete :destroy, params: { organization_id: organization.id, id: template.id }
      expect(response).to redirect_to(organization_prompt_templates_path(organization))
    end
  end

  describe 'authorization' do
    let(:unauthorized_person) { create(:person) }
    let(:unauthorized_teammate) { create(:teammate, person: unauthorized_person, organization: organization, can_manage_prompts: false) }
    let(:template) { create(:prompt_template, company: organization) }

    before do
      sign_in_as_teammate(unauthorized_person, organization)
    end

    it 'redirects with alert when unauthorized' do
      get :index, params: { organization_id: organization.id }
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to new' do
      get :new, params: { organization_id: organization.id }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to create' do
      post :create, params: {
        organization_id: organization.id,
        prompt_template: { title: 'New Template' }
      }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to edit' do
      get :edit, params: { organization_id: organization.id, id: template.id }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to update' do
      patch :update, params: {
        organization_id: organization.id,
        id: template.id,
        prompt_template: { title: 'Updated Title' }
      }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it 'prevents access to destroy' do
      delete :destroy, params: { organization_id: organization.id, id: template.id }
      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end
  end

  describe 'root_company handling' do
    let(:root_company) { create(:organization, :company) }
    let(:team) { create(:organization, :team, parent: root_company) }
    let!(:root_company_teammate) { create(:teammate, person: person, organization: root_company, type: 'CompanyTeammate', can_manage_prompts: true) }
    let!(:root_template) { create(:prompt_template, company: root_company) }

    before do
      sign_in_as_teammate(person, root_company)
      # Clear controller cache to ensure fresh teammate load
      controller.instance_variable_set(:@current_company_teammate, nil)
      CompanyTeammate.connection.clear_query_cache
    end

    it 'shows templates from root company in index' do
      get :index, params: { organization_id: root_company.id }
      expect(response).to have_http_status(:success)
      # The scope should return templates from root_company
      expect(assigns(:prompt_templates)).to include(root_template)
    end

    it 'creates templates for root company' do
      expect {
        post :create, params: {
          organization_id: root_company.id,
          prompt_template: {
            title: 'New Template',
            description: 'A new template'
          }
        }
      }.to change { PromptTemplate.count }.by(1)

      created_template = PromptTemplate.last
      expect(created_template.company_id).to eq(root_company.id)
    end
  end

  describe 'template not found' do
    let(:other_company) { create(:organization, :company) }
    let(:other_template) { create(:prompt_template, company: other_company) }

    it 'redirects with alert when template not found' do
      get :edit, params: { organization_id: organization.id, id: other_template.id }
      expect(response).to redirect_to(organization_prompt_templates_path(organization))
      expect(flash[:alert]).to match(/not found/i)
    end
  end
end

