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

    it 'assigns active templates and template prompts' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:active_templates)).to be_present
      expect(assigns(:template_prompts)).to be_a(Hash)
    end
  end

  describe 'GET #customize_view' do
    let(:other_template) { create(:prompt_template, company: organization, available_at: Date.current) }
    let(:other_person) { create(:person) }
    let(:other_teammate) { CompanyTeammate.find_or_create_by!(person: other_person, organization: organization) }

    before do
      other_teammate # Create the other teammate
    end

    it 'renders the customize_view template with overlay layout' do
      get :customize_view, params: { organization_id: organization.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:customize_view)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'assigns current filters, sort, view, and spotlight from params' do
      get :customize_view, params: {
        organization_id: organization.id,
        template: template.id.to_s,
        status: 'open',
        teammate: teammate.id.to_s,
        sort: 'updated_at_desc',
        view: 'table',
        spotlight: 'overview'
      }
      expect(assigns(:current_filters)[:template]).to eq(template.id.to_s)
      expect(assigns(:current_filters)[:status]).to eq('open')
      expect(assigns(:current_filters)[:teammate]).to eq(teammate.id.to_s)
      expect(assigns(:current_sort)).to eq('updated_at_desc')
      expect(assigns(:current_view)).to eq('table')
      expect(assigns(:current_spotlight)).to eq('overview')
    end

    it 'sets default values when params are not provided' do
      get :customize_view, params: { organization_id: organization.id }
      expect(assigns(:current_sort)).to eq('created_at_desc')
      expect(assigns(:current_view)).to eq('table')
      expect(assigns(:current_spotlight)).to eq('overview')
      expect(assigns(:current_filters)).to be_a(Hash)
    end

    it 'sets return_url and return_text' do
      get :customize_view, params: { organization_id: organization.id }
      expect(assigns(:return_url)).to include(organization_prompts_path(organization))
      expect(assigns(:return_text)).to eq('Back to Prompts')
    end

    it 'preserves current params in return_url' do
      get :customize_view, params: {
        organization_id: organization.id,
        template: template.id.to_s,
        status: 'open'
      }
      return_url = assigns(:return_url)
      expect(return_url).to include("template=#{template.id}")
      expect(return_url).to include('status=open')
    end

    it 'assigns available templates' do
      get :customize_view, params: { organization_id: organization.id }
      expect(assigns(:available_templates)).to include(template)
      expect(assigns(:available_templates)).to include(other_template)
    end

    it 'assigns available teammates' do
      get :customize_view, params: { organization_id: organization.id }
      expect(assigns(:available_teammates)).to include(teammate)
      expect(assigns(:available_teammates)).to include(other_teammate)
    end

    it 'requires authorization' do
      other_company = create(:organization, :company)
      other_company_person = create(:person)
      sign_in_as_teammate(other_company_person, other_company)
      
      get :customize_view, params: { organization_id: organization.id }
      expect(response).to have_http_status(:redirect)
    end

    it 'handles status filter "all" correctly' do
      get :customize_view, params: {
        organization_id: organization.id,
        status: 'all'
      }
      # When status is 'all', it should not be included in filters
      expect(assigns(:current_filters)[:status]).to be_nil
    end

    it 'handles blank template filter correctly' do
      get :customize_view, params: {
        organization_id: organization.id,
        template: ''
      }
      expect(assigns(:current_filters)[:template]).to be_nil
    end

    it 'handles blank teammate filter correctly' do
      get :customize_view, params: {
        organization_id: organization.id,
        teammate: ''
      }
      expect(assigns(:current_filters)[:teammate]).to be_nil
    end
  end

  describe 'GET #new (DEPRECATED - action does not exist)' do
    skip 'These specs test a non-existent action - prompts routes exclude :new' do
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

    it 'assigns existing open prompts keyed by template id with at most one per template' do
      other_template = create(:prompt_template, company: organization, available_at: Date.current)
      prompt1 = create(:prompt, :open, company_teammate: teammate, prompt_template: template)
      prompt2 = create(:prompt, :open, company_teammate: teammate, prompt_template: other_template)

      get :new, params: { organization_id: organization.id }
      existing_prompts = assigns(:existing_open_prompts)

      expect(existing_prompts).to include(template.id => prompt1)
      expect(existing_prompts).to include(other_template.id => prompt2)
      expect(existing_prompts.keys).to contain_exactly(template.id, other_template.id)
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
    end # end skip block
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
        expect(response).to redirect_to(organization_prompts_path(organization))
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

      it 'creates a new prompt and redirects to edit' do
        expect {
          post :create, params: {
            organization_id: organization.id,
            template_id: template.id
          }
        }.to change { Prompt.count }.by(1)

        new_prompt = Prompt.last
        expect(new_prompt.prompt_template).to eq(template)
        expect(new_prompt.open?).to be true
        expect(existing_open.reload.open?).to be true

        expect(response).to redirect_to(edit_organization_prompt_path(organization, new_prompt))
        expect(flash[:notice]).to eq('Prompt started successfully.')
      end
    end
  end

  describe 'GET #show (DEPRECATED - action does not exist)' do
    skip 'These specs test a non-existent action - prompts routes exclude :show' do
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
    end # end skip block
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

    skip 'view_style parameter not implemented in controller' do
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
    end # end skip

    context 'when prompt is closed' do
      let(:closed_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template) }

      it 'allows viewing closed prompts (read-only mode)' do
        get :edit, params: { organization_id: organization.id, id: closed_prompt.id }
        expect(response).to have_http_status(:success)
        expect(assigns(:can_edit)).to be false
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
        expect(response).to redirect_to(edit_organization_prompt_path(organization, open_prompt))
      end

      skip 'switch_to_view parameter not implemented' do
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
      end # end skip
    end

    context 'when prompt is closed' do
      let(:closed_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template) }

      it 'redirects with alert' do
        patch :update, params: {
          organization_id: organization.id,
          id: closed_prompt.id,
          prompt_answers: {}
        }
        expect(response).to redirect_to(edit_organization_prompt_path(organization, closed_prompt))
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

    it 'redirects to edit prompt' do
      patch :close, params: { organization_id: organization.id, id: open_prompt.id }
      expect(response).to redirect_to(edit_organization_prompt_path(organization, open_prompt))
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

  describe 'PATCH #update_view' do
    it 'redirects to index with view customization params' do
      patch :update_view, params: {
        organization_id: organization.id,
        template: template.id.to_s,
        status: 'open',
        teammate: teammate.id.to_s,
        sort: 'updated_at_desc',
        view: 'table',
        spotlight: 'overview'
      }
      expect(response).to have_http_status(:redirect)
      redirect_url = response.redirect_url
      expect(redirect_url).to include(organization_prompts_path(organization))
      expect(redirect_url).to include("template=#{template.id}")
      expect(redirect_url).to include('status=open')
      expect(redirect_url).to include("teammate=#{teammate.id}")
      expect(redirect_url).to include('sort=updated_at_desc')
      expect(redirect_url).to include('view=table')
      expect(redirect_url).to include('spotlight=overview')
    end

    it 'excludes controller, action, authenticity_token, _method, and commit params' do
      patch :update_view, params: {
        organization_id: organization.id,
        controller: 'organizations/prompts',
        action: 'update_view',
        authenticity_token: 'token',
        _method: 'patch',
        commit: 'Apply View',
        template: template.id.to_s,
        status: 'open'
      }
      expect(response).to have_http_status(:redirect)
      redirect_url = response.redirect_url
      expect(redirect_url).to include("template=#{template.id}")
      expect(redirect_url).to include('status=open')
      expect(redirect_url).not_to include('controller=')
      expect(redirect_url).not_to include('action=')
      expect(redirect_url).not_to include('authenticity_token=')
      expect(redirect_url).not_to include('_method=')
      expect(redirect_url).not_to include('commit=')
    end

    it 'requires authorization' do
      other_company = create(:organization, :company)
      other_company_person = create(:person)
      sign_in_as_teammate(other_company_person, other_company)
      
      patch :update_view, params: {
        organization_id: organization.id,
        template: template.id.to_s
      }
      expect(response).to have_http_status(:redirect)
    end

    it 'handles empty filter values correctly' do
      patch :update_view, params: {
        organization_id: organization.id,
        template: '',
        status: 'all',
        teammate: '',
        sort: 'created_at_desc'
      }
      redirect_url = response.redirect_url
      # Empty values should not appear in the URL or should be handled appropriately
      expect(redirect_url).to include('sort=created_at_desc')
    end

    it 'preserves all valid filter and sort params' do
      patch :update_view, params: {
        organization_id: organization.id,
        template: template.id.to_s,
        status: 'closed',
        sort: 'template_title'
      }
      redirect_url = response.redirect_url
      expect(redirect_url).to include("template=#{template.id}")
      expect(redirect_url).to include('status=closed')
      expect(redirect_url).to include('sort=template_title')
    end
  end

  describe 'GET #manage_goals' do
    let(:open_prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }
    let!(:goal1) { create(:goal, owner: teammate, creator: teammate, company: organization) }
    let!(:goal2) { create(:goal, owner: teammate, creator: teammate, company: organization) }

    it 'renders the manage_goals template with overlay layout' do
      get :manage_goals, params: { organization_id: organization.id, id: open_prompt.id }
      expect(response).to have_http_status(:success)
      expect(response).to render_template(:manage_goals)
      expect(response).to render_template(layout: 'overlay')
    end

    it 'assigns available goals with status' do
      get :manage_goals, params: { organization_id: organization.id, id: open_prompt.id }
      expect(assigns(:available_goals_with_status)).to be_present
      expect(assigns(:available_goals_with_status).length).to be >= 2
    end

    it 'marks already linked goals' do
      PromptGoal.create!(prompt: open_prompt, goal: goal1)
      get :manage_goals, params: { organization_id: organization.id, id: open_prompt.id }
      goal_status = assigns(:available_goals_with_status).find { |gs| gs[:goal] == goal1 }
      expect(goal_status[:already_linked]).to be true
    end

    it 'assigns return_url and return_text from params' do
      return_url = '/close_tab?return_text=close+tab+when+done'
      return_text = 'close tab when done'
      get :manage_goals, params: { 
        organization_id: organization.id, 
        id: open_prompt.id,
        return_url: return_url,
        return_text: return_text
      }
      expect(assigns(:return_url)).to eq(return_url)
      expect(assigns(:return_text)).to eq(return_text)
    end

    context 'when prompt is closed' do
      let(:closed_prompt) { create(:prompt, :closed, company_teammate: teammate, prompt_template: template) }

      it 'denies access' do
        get :manage_goals, params: { organization_id: organization.id, id: closed_prompt.id }
        # Pundit redirects unauthorized users
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  describe 'authorization' do
    let(:other_person) { create(:person) }
    let(:other_teammate) { CompanyTeammate.create!(person: other_person, organization: organization) }
    let(:other_prompt) { create(:prompt, company_teammate: other_teammate, prompt_template: template) }

    context 'when user tries to access another user\'s prompt' do
      skip 'denies show access (show action does not exist)' do
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

      it 'denies manage_goals access' do
        get :manage_goals, params: { organization_id: organization.id, id: other_prompt.id }
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
        expect(response).to redirect_to(organization_prompts_path(organization))
        expect(flash[:alert]).to be_present
      end
    end

    context 'when user is not a CompanyTeammate' do
      let(:team) { create(:organization, :team, parent: organization) }
      let(:team_teammate) { create(:teammate, person: person, organization: team) }

      before do
        session[:current_company_teammate_id] = team_teammate.id
      end

      it 'redirects to dashboard with alert (org access denied)' do
        post :create, params: {
          organization_id: organization.id,
          template_id: template.id
        }
        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to eq("You don't have access to that organization.")
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
        expect(response).to redirect_to(organization_prompts_path(organization))
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

    it 'assigns active templates' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:active_templates)).to include(template)
    end

    it 'assigns template prompts' do
      get :index, params: { organization_id: organization.id }
      expect(assigns(:template_prompts)).to be_a(Hash)
      expect(assigns(:template_prompts)[template.id]).to be_present
    end

    skip 'These specs test features not in current index (use customize_view instead)' do
    it 'assigns current filters' do
      get :index, params: { organization_id: organization.id, template: template.id, status: 'open' }
      expect(assigns(:current_filters)).to include(template: template.id.to_s, status: 'open')
    end

    it 'assigns current sort' do
      get :index, params: { organization_id: organization.id, sort: 'created_at_asc' }
      expect(assigns(:current_sort)).to eq('created_at_asc')
    end

    it 'paginates results' do
      prompt1.close! if prompt1.open?
      prompt2.close! if prompt2.open?
      30.times do |i|
        create(:prompt, :closed, company_teammate: teammate, prompt_template: template, created_at: i.days.ago)
      end
      get :index, params: { organization_id: organization.id }
      expect(assigns(:prompts).count).to eq(25)
      expect(assigns(:pagy)).to be_present
      expect(assigns(:pagy).items).to eq(25)
    end
    end # end skip
  end
end

