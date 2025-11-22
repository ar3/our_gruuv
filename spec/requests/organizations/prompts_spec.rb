require 'rails_helper'

RSpec.describe 'Organizations::Prompts', type: :request do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, :company) }
  let(:template) { create(:prompt_template, :available, company: organization) }
  
  let(:teammate) do
    CompanyTeammate.find_or_create_by!(person: person, organization: organization)
  end

  before do
    sign_in_as_teammate_for_request(person, organization)
    # Ensure template is available and belongs to the organization
    template.update!(company: organization, available_at: Date.current) if template.company_id != organization.id
  end

  describe 'GET /organizations/:organization_id/prompts' do
    it 'renders the index page' do
      get organization_prompts_path(organization)
      expect(response).to have_http_status(:success)
    end
  end


  describe 'GET /organizations/:organization_id/prompts/new' do
    before do
      # Ensure template is available and belongs to the organization
      template.update!(company: organization, available_at: Date.current) if template.company_id != organization.id
    end

    it 'renders the new page' do
      get new_organization_prompt_path(organization)
      expect(response).to have_http_status(:success)
    end

    it 'shows available templates' do
      get new_organization_prompt_path(organization)
      expect(response.body).to include(template.title)
    end

    context 'when user has open prompt for a template' do
      let!(:existing_open) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }

      it 'shows warning for that template' do
        get new_organization_prompt_path(organization)
        expect(response.body).to include('open prompt')
      end
    end
  end

  describe 'POST /organizations/:organization_id/prompts' do
    context 'with valid template' do
      it 'creates a new prompt' do
        expect {
          post organization_prompts_path(organization), params: {
            template_id: template.id
          }
        }.to change { Prompt.count }.by(1)
      end

      it 'redirects to edit prompt' do
        post organization_prompts_path(organization), params: {
          template_id: template.id
        }
        prompt = Prompt.last
        expect(response).to redirect_to(edit_organization_prompt_path(organization, prompt))
      end
    end

    context 'when template is not found' do
      it 'redirects with alert' do
        post organization_prompts_path(organization), params: {
          template_id: 99999
        }
        expect(response).to redirect_to(new_organization_prompt_path(organization))
        expect(flash[:alert]).to be_present
      end
    end

    context 'when user already has open prompt for same template' do
      let!(:existing_open) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }

      it 'closes existing prompt and creates new one' do
        expect {
          post organization_prompts_path(organization), params: {
            template_id: template.id
          }
        }.to change { Prompt.count }.by(1)
        
        existing_open.reload
        expect(existing_open.closed?).to be true
      end
    end

    context 'when user has open prompt for different template' do
      let(:other_template) { create(:prompt_template, company: organization, available_at: Date.current) }
      let!(:existing_open) { create(:prompt, :open, company_teammate: teammate, prompt_template: other_template) }

      it 'redirects with alert' do
        post organization_prompts_path(organization), params: {
          template_id: template.id
        }
        expect(response).to redirect_to(new_organization_prompt_path(organization))
        expect(flash[:alert]).to match(/already have an open prompt/)
      end
    end
  end

  describe 'GET /organizations/:organization_id/prompts/:id' do
    let(:prompt) { create(:prompt, company_teammate: teammate, prompt_template: template) }

    it 'renders the show page' do
      get organization_prompt_path(organization, prompt)
      expect(response).to have_http_status(:success)
    end

  end

  describe 'GET /organizations/:organization_id/prompts/:id/edit' do
    let(:open_prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }
    let!(:question) { create(:prompt_question, prompt_template: template) }

    it 'renders the edit page' do
      get edit_organization_prompt_path(organization, open_prompt)
      expect(response).to have_http_status(:success)
    end

    it 'defaults to split view' do
      get edit_organization_prompt_path(organization, open_prompt)
      expect(response.body).to include('Split View')
    end

    it 'renders split view when requested' do
      get edit_organization_prompt_path(organization, open_prompt, view: 'split')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Split View')
      expect(response.body).to include('col-sm-3')
      expect(response.body).to include('col-sm-9')
    end

    it 'renders vertical view when requested' do
      get edit_organization_prompt_path(organization, open_prompt, view: 'vertical')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Vertical View')
    end
  end

  describe 'PATCH /organizations/:organization_id/prompts/:id' do
    let(:open_prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }
    let(:question) { create(:prompt_question, prompt_template: template) }

    it 'updates the prompt' do
      patch organization_prompt_path(organization, open_prompt), params: {
        prompt_answers: {
          question.id.to_s => {
            text: 'My answer'
          }
        }
      }
      expect(response).to redirect_to(organization_prompt_path(organization, open_prompt))
    end
  end

  describe 'PATCH /organizations/:organization_id/prompts/:id/close' do
    let(:open_prompt) { create(:prompt, :open, company_teammate: teammate, prompt_template: template) }

    it 'closes the prompt' do
      patch close_organization_prompt_path(organization, open_prompt)
      expect(response).to redirect_to(organization_prompt_path(organization, open_prompt))
      expect(open_prompt.reload.closed?).to be true
    end
  end
end

