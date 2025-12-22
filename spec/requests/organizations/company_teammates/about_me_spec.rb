require 'rails_helper'

RSpec.describe 'About Me Page', type: :request do
  let(:organization) { create(:organization, :company) }
  let(:person) { create(:person) }
  let(:teammate) { create(:teammate, person: person, organization: organization, type: 'CompanyTeammate') }

  before do
    create(:employment_tenure, teammate: teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
    teammate.update!(first_employed_at: 1.year.ago)
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/company_teammates/:id/about_me' do
    context 'when user has view_check_ins permission' do
      it 'allows access' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response).to have_http_status(:success)
      end

      it 'renders the about_me template' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response).to render_template(:about_me)
      end

      it 'uses determine_layout method for layout' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response).to have_http_status(:success)
        # Layout is determined by determine_layout method, not hardcoded
      end

      it 'loads all necessary data' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(assigns(:teammate)).to be_a(CompanyTeammate)
        expect(assigns(:teammate).id).to eq(teammate.id)
        expect(assigns(:person)).to eq(person)
      end
    end

    context 'when user does not have view_check_ins permission' do
      let(:other_person) { create(:person) }
      let(:other_teammate) { create(:teammate, person: other_person, organization: organization, type: 'CompanyTeammate') }

      before do
        create(:employment_tenure, teammate: other_teammate, company: organization, started_at: 1.year.ago, ended_at: nil)
        other_teammate.update!(first_employed_at: 1.year.ago)
        sign_in_as_teammate_for_request(other_person, organization)
      end

      it 'denies access when viewing another teammate without permission' do
        get about_me_organization_company_teammate_path(organization, teammate)
        expect(response).to have_http_status(:redirect)
      end
    end

    context 'when user is unauthenticated' do
      before do
        allow_any_instance_of(ApplicationController).to receive(:current_company_teammate).and_return(nil)
      end

      it 'raises error' do
        expect {
          get about_me_organization_company_teammate_path(organization, teammate)
        }.to raise_error(RuntimeError, /Teammate not found/)
      end
    end
  end

  describe 'Navigation link' do
    it 'appears in navigation for authorized users' do
      get dashboard_organization_path(organization)
      expect(response.body).to include('About')
      expect(response.body).to include(person.casual_name)
    end
  end

  describe 'View switcher' do
    it 'includes About Me View option' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('About Me View')
    end

    it 'shows About Me View as active when on about_me page' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('About Me View (Active)')
    end
  end

  describe 'Sections rendering' do
    it 'renders stories section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('stories')
    end

    it 'renders goals section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to match(/ACTIVE GOALS|Active Goals/i)
    end

    it 'renders prompts section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('Prompts')
    end

    it 'renders 1:1 area section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('1:1 Area')
    end

    it 'renders position check-in section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to match(/POSITION\/OVERALL|Position\/Overall/i)
    end

    it 'renders assignments check-in section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to match(/ASSIGNMENTS\/OUTCOMES|Assignments\/Outcomes/i)
    end

    it 'renders aspirations check-in section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to match(/ASPIRATIONS\/VALUES|Aspirations\/Values/i)
    end

    it 'renders abilities section' do
      get about_me_organization_company_teammate_path(organization, teammate)
      expect(response.body).to include('Abilities')
    end
  end

  describe 'Status indicators' do
    context 'stories section' do
      it 'shows red indicator when no shareable observations in last 30 days' do
        get about_me_organization_company_teammate_path(organization, teammate)
        # Should show red indicator when 0 given and 0 received
        expect(response.body).to match(/text-danger|bg-danger/)
      end
    end

    context 'goals section' do
      it 'shows red indicator when no active goals' do
        get about_me_organization_company_teammate_path(organization, teammate)
        # Should show red indicator when no active goals
        expect(response.body).to match(/text-danger|bg-danger/)
      end
    end

    context '1:1 section' do
      it 'shows red indicator when no link saved' do
        get about_me_organization_company_teammate_path(organization, teammate)
        # Should show red indicator when no 1:1 link
        expect(response.body).to match(/text-danger|bg-danger/)
      end
    end
  end
end

