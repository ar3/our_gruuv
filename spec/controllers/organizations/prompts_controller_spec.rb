require 'rails_helper'

RSpec.describe Organizations::PromptsController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:template) { create(:prompt_template, company: organization, available_at: Date.current) }
  
  let(:teammate) do
    CompanyTeammate.find_or_create_by!(person: person, organization: organization)
  end

  before do
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #index' do
    let!(:prompt1) { create(:prompt, company_teammate: teammate, prompt_template: template) }
    let!(:prompt2) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template) }

    it 'renders the index template' do
      get :index, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:index)
    end

    it 'assigns prompts using policy scope' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:prompts)).to be_present
    end
  end

  describe 'GET #customize_view' do
    it 'renders the customize_view template with overlay layout' do
      get :customize_view, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:customize_view)
      expect(response).to render_template(layout: 'overlay')
    end
  end

  describe 'GET #new' do
    it 'renders the new template' do
      get :new, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:new)
    end

    it 'assigns available templates' do
      get :new, params: { organization_id: organization.id }
      expect(assigns(:available_templates)).to include(template)
    end

    it 'assigns existing open prompts' do
      existing_prompt = create(:prompt, :open, company_teammate: teammate, prompt_template: template)
      get :new, params: { organization_id: organization.id }
      expect(assigns(:existing_open_prompts)).to include(template.id => existing_prompt)
    end

    context 'when user is not a CompanyTeammate' do
      let(:team) { create(:organization, :team, parent: organization) }
      let(:team_teammate) { create(:teammate, person: person, organization: team) }

      before do
        # Remove any existing CompanyTeammate for this person in the organization
        person.teammates.where(organization: organization, type: 'CompanyTeammate').destroy_all
        # Sign in as team teammate (not CompanyTeammate)
        session[:current_company_teammate_id] = team_teammate.id
      end

      it 'redirects with alert' do
        get :new, params: { organization_id: organization.id }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'POST #create' do
    context 'with valid template' do
      it 'creates a new prompt' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            template_id: template.id
          }
        }.to change { Prompt.count }.by(1)
      end

      it 'redirects to edit prompt' do
        post :create, params: {
          organization_id: organization.id,
          template_id: template.id
        }
        prompt = Prompt.last
        expect(response).to redirect_to(edit_organization_prompt_path(organization, prompt))
      end
    end

    context 'when template is not available' do
      let(:unavailable_template) { create(:prompt_template, company: organization, available_at: nil) }

      it 'redirects with alert' do
        post :create, params: {
          organization_id: organization.id,
          template_id: unavailable_template.id
        }
        expect(response).to redirect_to(new_organization_prompt_path(organization))
        expect(flash[:alert]).to be_present
      end
    end

    context 'when user already has open prompt for same template' do
      let!(:existing_open) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }

      it 'closes existing prompt and creates new one' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            template_id: template.id
          }
        }.to change { Prompt.count }.by(1)
        
        existing_open.reload
        expect(existing_open.closed?).to be true
        
        new_prompt = Prompt.last
        expect(new_prompt).not_to eq(existing_open)
        expect(new_prompt.open?).to be true
      end
    end

    context 'when user has open prompt for different template' do
      let(:other_template) { create(:prompt_template, company: organization, available_at: Date.current) }
      let!(:existing_open) { create(:prompt, :open, company_teammate: teammate, prompt_template: other_template) }

      it 'redirects with alert' do
        post :create, params: {
          organization_id: organization.id,
          template_id: template.id
        }
        expect(response).to redirect_to(new_organization_prompt_path(organization))
        expect(flash[:alert]).to match(/already have an open prompt/)
      end
    end
  end

  describe 'GET #show' do
    let(:prompt) { create(:prompt, company_teammate: teammate, prompt_template: template) }
    let!(:question) { create(:prompt_question, prompt_template: template) }

    it 'renders the show template' do
      get :show, params: { organization_id: organization.id, id: prompt.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:show)
    end

    it 'assigns the prompt and answers' do
      get :show, params: { organization_id: organization.id, id: prompt.id }
      expect(assigns(:prompt)).to eq(prompt)
      expect(assigns(:prompt_answers)).to be_an(Array)
    end
  end

  describe 'GET #edit' do
    let(:open_prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }
    let!(:question) { create(:prompt_question, prompt_template: template) }

    it 'renders the edit template' do
      get :edit, params: { organization_id: organization.id, id: open_prompt.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:edit)
    end

    it 'assigns prompt, template, questions, and answers' do
      get :edit, params: { organization_id: organization.id, id: open_prompt.id }
      expect(assigns(:prompt)).to eq(open_prompt)
      expect(assigns(:prompt_template)).to eq(template)
      expect(assigns(:prompt_questions)).to be_present
      expect(assigns(:prompt_answers)).to be_present
    end

    it 'defaults to split view style' do
      get :edit, params: { organization_id: organization.id, id: open_prompt.id }
      expect(assigns(:view_style)).to eq('split')
    end

    it 'accepts split view style parameter' do
      get :edit, params: { organization_id: organization.id, id: open_prompt.id, view: 'split' }
      expect(assigns(:view_style)).to eq('split')
    end

    it 'rejects invalid view style and defaults to split' do
      get :edit, params: { organization_id: organization.id, id: open_prompt.id, view: 'invalid' }
      expect(assigns(:view_style)).to eq('split')
    end

    context 'when prompt is closed' do
      let(:closed_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template) }

      it 'redirects with alert' do
        get :edit, params: { organization_id: organization.id, id: closed_prompt.id }
        expect(response).to redirect_to(organization_prompt_path(organization, closed_prompt))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'PATCH #update' do
    let(:open_prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }
    let(:question) { create(:prompt_question, prompt_template: template) }

    context 'with valid params' do
      it 'updates prompt answers' do
        patch :update, params: {
          organization_id: organization.id,
          id: open_prompt.id,
          prompt_answers: {
            question.id.to_s => {
              text: 'My answer'
            }
          }
        }
        answer = open_prompt.prompt_answers.find_by(prompt_question: question)
        expect(answer.text).to eq('My answer')
      end

      it 'redirects to show prompt' do
        patch :update, params: {
          organization_id: organization.id,
          id: open_prompt.id,
          prompt_answers: {
            question.id.to_s => {
              text: 'My answer'
            }
          }
        }
        expect(response).to redirect_to(organization_prompt_path(organization, open_prompt))
      end

      it 'redirects to edit page with new view when switch_to_view parameter is present' do
        patch :update, params: {
          organization_id: organization.id,
          id: open_prompt.id,
          prompt_answers: {
            question.id.to_s => { text: 'My answer' }
          },
          switch_to_view: 'split'
        }
        expect(response).to redirect_to(edit_organization_prompt_path(organization, open_prompt, view: 'split'))
        expect(flash[:notice]).to eq('Prompt updated successfully.')
      end

      it 'saves answers before switching views' do
        answer_text = 'Updated answer text'
        patch :update, params: {
          organization_id: organization.id,
          id: open_prompt.id,
          prompt_answers: {
            question.id.to_s => { text: answer_text }
          },
          switch_to_view: 'vertical'
        }
        
        answer = open_prompt.reload.prompt_answers.find_by(prompt_question_id: question.id)
        expect(answer.text).to eq(answer_text)
        expect(response).to redirect_to(edit_organization_prompt_path(organization, open_prompt, view: 'vertical'))
      end
    end

    context 'when prompt is closed' do
      let(:closed_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template) }

      it 'redirects with alert' do
        patch :update, params: {
          organization_id: organization.id,
          id: closed_prompt.id,
          prompt_answers: {}
        }
        expect(response).to redirect_to(organization_prompt_path(organization, closed_prompt))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'PATCH #close' do
    let(:open_prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }

    it 'closes the prompt' do
      expect(open_prompt.open?).to be true
      patch :close, params: { organization_id: organization.id, id: open_prompt.id }
      open_prompt.reload
      expect(open_prompt.closed?).to be true
    end

    it 'redirects to show prompt' do
      patch :close, params: { organization_id: organization.id, id: open_prompt.id }
      expect(response).to redirect_to(organization_prompt_path(organization, open_prompt))
    end

    context 'when prompt is already closed' do
      let(:closed_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template) }

      it 'redirects with alert' do
        patch :close, params: { organization_id: organization.id, id: closed_prompt.id }
        # When authorization fails, it redirects to root
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'POST #update_view' do
    it 'redirects to index with params' do
      post :update_view, params: {
        organization_id: organization.id,
        template: template.id,
        status: 'open',
        sort: 'created_at_desc'
      }
      # The redirect includes organization_id in the URL params, which is expected behavior
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("template=#{template.id}")
      expect(response.location).to include('status=open')
      expect(response.location).to include('sort=created_at_desc')
    end

    it 'excludes controller, action, authenticity_token, _method, and commit params' do
      post :update_view, params: {
        organization_id: organization.id,
        controller: 'organizations/prompts',
        action: 'update_view',
        authenticity_token: 'token',
        _method: 'post',
        commit: 'Save',
        template: template.id
      }
      # The redirect includes organization_id in the URL params, which is expected behavior
      expect(response).to have_http_status(:redirect)
      expect(response.location).to include("template=#{template.id}")
      expect(response.location).not_to include('controller=')
      expect(response.location).not_to include('action=')
      expect(response.location).not_to include('authenticity_token=')
      expect(response.location).not_to include('_method=')
      expect(response.location).not_to include('commit=')
    end
  end

  describe 'authorization' do
    let(:other_person) { create(:person) }
    let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: organization) }
    let(:other_prompt) { create(:prompt, company_teammate: other_teammate, prompt_template: template) }

    context 'when user tries to access another user\'s prompt' do
      it 'denies show access' do
        get :show, params: { organization_id: organization.id, id: other_prompt.id }
        # Pundit redirects unauthorized users, so we check for redirect
        expect(response).to have_http_status(:redirect)
      end

      it 'denies edit access' do
        get :edit, params: { organization_id: organization.id, id: other_prompt.id }
        # Pundit redirects unauthorized users, so we check for redirect
        expect(response).to have_http_status(:redirect)
      end

      it 'denies update access' do
        patch :update, params: {
          organization_id: organization.id,
          id: other_prompt.id,
          prompt_answers: {}
        }
        # Pundit redirects unauthorized users, so we check for redirect
        expect(response).to have_http_status(:redirect)
      end

      it 'denies close access' do
        patch :close, params: { organization_id: organization.id, id: other_prompt.id }
        # Pundit redirects unauthorized users, so we check for redirect
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'POST #create' do
    context 'when template is not found' do
      it 'redirects with alert' do
        post :create, params: {
          organization_id: organization.id,
          template_id: 99999
        }
        expect(response).to redirect_to(new_organization_prompt_path(organization))
        expect(flash[:alert]).to be_present
      end
    end

    context 'when user is not a CompanyTeammate' do
      let(:team) { create(:organization, :team, parent: organization) }
      let(:team_teammate) { create(:teammate, person: person, organization: team) }

      before do
        session[:current_company_teammate_id] = team_teammate.id
      end

      it 'redirects with alert' do
        post :create, params: {
          organization_id: organization.id,
          template_id: template.id
        }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include(organization_prompts_path(organization))
      end
    end

    context 'when template belongs to different company' do
      let(:other_company) { create(:organization, :company) }
      let(:other_template) { create(:prompt_template, company: other_company) }

      it 'redirects with alert' do
        post :create, params: {
          organization_id: organization.id,
          template_id: other_template.id
        }
        expect(response).to redirect_to(new_organization_prompt_path(organization))
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe 'PATCH #update' do
    let(:open_prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }
    let(:question) { create(:prompt_question, prompt_template: template) }
    let(:updater_teammate) { teammate }

    context 'when text changes' do
      let!(:existing_answer) { create(:prompt_answer, prompt: open_prompt, prompt_question: question, text: 'Original text') }

      it 'updates updated_by_company_teammate_id' do
        patch :update, params: {
          organization_id: organization.id,
          id: open_prompt.id,
          prompt_answers: {
            question.id.to_s => {
              text: 'Updated text'
            }
          }
        }
        existing_answer.reload
        expect(existing_answer.text).to eq('Updated text')
        expect(existing_answer.updated_by_company_teammate_id).to eq(updater_teammate.id)
      end
    end

    context 'when text does not change' do
      let!(:existing_answer) { create(:prompt_answer, prompt: open_prompt, prompt_question: question, text: 'Same text') }

      it 'does not update updated_by_company_teammate_id' do
        original_updated_by = existing_answer.updated_by_company_teammate_id
        patch :update, params: {
          organization_id: organization.id,
          id: open_prompt.id,
          prompt_answers: {
            question.id.to_s => {
              text: 'Same text'
            }
          }
        }
        existing_answer.reload
        expect(existing_answer.updated_by_company_teammate_id).to eq(original_updated_by)
      end
    end

    context 'when creating new answer' do
      it 'creates new prompt answer' do
        expect {
          patch :update, params: {
            organization_id: organization.id,
            id: open_prompt.id,
            prompt_answers: {
              question.id.to_s => {
                text: 'New answer'
              }
            }
          }
        }.to change { PromptAnswer.count }.by(1)
        
        answer = open_prompt.prompt_answers.find_by(prompt_question: question)
        expect(answer.text).to eq('New answer')
      end
    end

    context 'with invalid params' do
      it 'renders edit with errors' do
        # Create a duplicate answer to trigger validation error
        other_question = create(:prompt_question, prompt_template: template)
        create(:prompt_answer, prompt: open_prompt, prompt_question: other_question)
        
        # Try to create duplicate answer
        allow_any_instance_of(PromptAnswer).to receive(:save!).and_raise(ActiveRecord::RecordInvalid.new(PromptAnswer.new))
        
        patch :update, params: {
          organization_id: organization.id,
          id: open_prompt.id,
          prompt_answers: {
            other_question.id.to_s => {
              text: 'Duplicate'
            }
          }
        }
        expect(response).to render_template(:edit)
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe 'GET #index' do
    let!(:prompt1) { create(:prompt, company_teammate: teammate, prompt_template: template, created_at: 2.days.ago) }
    let!(:prompt2) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template, created_at: 1.day.ago) }

    it 'assigns available templates' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:available_templates)).to include(template)
    end

    it 'assigns available teammates' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:available_teammates)).to include(teammate)
    end

    it 'assigns current filters' do
      get :index, params: { organization_id: organization.id, template: template.id, status: 'open' }
      # Params come as strings, so template will be a string
      expect(assigns(:current_filters)).to include(template: template.id.to_s, status: 'open')
    end

    it 'assigns current sort' do
      get :index, params: { organization_id: organization.id, sort: 'created_at_asc' }
      expect(assigns(:current_sort)).to eq('created_at_asc')
    end

    it 'paginates results' do
      # Create more than 25 prompts to test pagination
      # Need to close existing prompts first, then create prompts owned by current user
      prompt1.close! if prompt1.open?
      prompt2.close! if prompt2.open?
      
      # Create 30 closed prompts owned by the current teammate
      30.times do |i|
        create(:prompt, :closed, company_teammate: teammate, prompt_template: template, created_at: i.days.ago)
      end
      
      get :index, params: { organization_id: organization.id }
      # Should paginate to 25 items per page
      expect(assigns(:prompts).count).to eq(25)
      expect(assigns(:pagy)).to be_present
      expect(assigns(:pagy).items).to eq(25)
    end
  end
end

