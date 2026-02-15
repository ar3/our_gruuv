require 'rails_helper'

RSpec.describe Organizations::TeamsController, type: :controller do
  let(:company) { create(:organization) }
  let(:admin_person) { create(:person, og_admin: true) }
  let(:admin_teammate) { create(:company_teammate, person: admin_person, organization: company, first_employed_at: 1.year.ago, can_manage_departments_and_teams: true) }
  let(:team) { create(:team, company: company) }

  before do
    session[:current_company_teammate_id] = admin_teammate.id
  end

  describe 'GET #index' do
    it 'returns success' do
      get :index, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns active teams' do
      active_team = create(:team, company: company)
      archived_team = create(:team, :archived, company: company)

      get :index, params: { organization_id: company.id }

      expect(assigns(:teams)).to include(active_team)
      expect(assigns(:teams)).not_to include(archived_team)
    end
  end

  describe 'GET #show' do
    it 'returns success' do
      get :show, params: { organization_id: company.id, id: team.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #new' do
    it 'returns success' do
      get :new, params: { organization_id: company.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'POST #create' do
    it 'creates a new team' do
      expect {
        post :create, params: { organization_id: company.id, team: { name: 'New Team' } }
      }.to change(Team, :count).by(1)
    end

    it 'redirects to teams index on success' do
      post :create, params: { organization_id: company.id, team: { name: 'New Team' } }
      expect(response).to redirect_to(organization_teams_path(company))
    end

    it 'renders new on failure' do
      post :create, params: { organization_id: company.id, team: { name: '' } }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response).to render_template(:new)
    end
  end

  describe 'GET #edit' do
    it 'returns success' do
      get :edit, params: { organization_id: company.id, id: team.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'PATCH #update' do
    it 'updates the team' do
      patch :update, params: { organization_id: company.id, id: team.id, team: { name: 'Updated Name' } }
      expect(team.reload.name).to eq('Updated Name')
    end

    it 'redirects to team show on success' do
      patch :update, params: { organization_id: company.id, id: team.id, team: { name: 'Updated Name' } }
      expect(response).to redirect_to(organization_team_path(company, team.reload))
    end

    it 'updates huddle_channel_id when Slack is configured' do
      channel = create(:third_party_object, :slack_channel, organization: company, third_party_id: 'C123', display_name: '#general')
      patch :update, params: { organization_id: company.id, id: team.id, team: { name: team.name, huddle_channel_id: channel.third_party_id } }
      expect(team.reload.huddle_channel_id).to eq(channel.third_party_id)
    end
  end

  describe 'PATCH #archive' do
    it 'soft deletes the team' do
      patch :archive, params: { organization_id: company.id, id: team.id }
      expect(team.reload.deleted_at).to be_present
    end

    it 'redirects to teams index' do
      patch :archive, params: { organization_id: company.id, id: team.id }
      expect(response).to redirect_to(organization_teams_path(company))
    end
  end

  describe 'GET #manage_members' do
    let!(:employed_teammate) { create(:company_teammate, organization: company, first_employed_at: 1.year.ago, last_terminated_at: nil) }
    let!(:not_employed_teammate) { create(:company_teammate, organization: company, first_employed_at: nil, last_terminated_at: nil) }
    let!(:terminated_teammate) { create(:company_teammate, organization: company, first_employed_at: 1.year.ago, last_terminated_at: 1.day.ago) }

    it 'returns success' do
      get :manage_members, params: { organization_id: company.id, id: team.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns only employed teammates' do
      get :manage_members, params: { organization_id: company.id, id: team.id }

      expect(assigns(:teammates)).to include(employed_teammate)
      expect(assigns(:teammates)).to include(admin_teammate)
      expect(assigns(:teammates)).not_to include(not_employed_teammate)
      expect(assigns(:teammates)).not_to include(terminated_teammate)
    end
  end

  describe 'PATCH #update_members' do
    let!(:teammate1) { create(:company_teammate, organization: company, first_employed_at: 1.year.ago) }
    let!(:teammate2) { create(:company_teammate, organization: company, first_employed_at: 1.year.ago) }

    it 'adds new members to the team' do
      expect {
        patch :update_members, params: { organization_id: company.id, id: team.id, teammate_ids: [teammate1.id, teammate2.id] }
      }.to change { team.team_members.count }.by(2)
    end

    it 'removes members from the team' do
      create(:team_member, team: team, company_teammate: teammate1)
      create(:team_member, team: team, company_teammate: teammate2)

      expect {
        patch :update_members, params: { organization_id: company.id, id: team.id, teammate_ids: [teammate1.id] }
      }.to change { team.team_members.count }.by(-1)

      expect(team.team_members.pluck(:company_teammate_id)).to eq([teammate1.id])
    end

    it 'redirects to team show' do
      patch :update_members, params: { organization_id: company.id, id: team.id, teammate_ids: [] }
      expect(response).to redirect_to(organization_team_path(company, team))
    end
  end
end
