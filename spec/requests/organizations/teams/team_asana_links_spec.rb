# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::Teams::TeamAsanaLinks', type: :request do
  let(:organization) { create(:organization) }
  let(:person) { create(:person) }
  let(:teammate) do
    create(:teammate, person: person, organization: organization,
           first_employed_at: 1.year.ago, last_terminated_at: nil,
           can_manage_departments_and_teams: true)
  end
  let(:team) { create(:team, company: organization, name: 'Engineering') }

  before do
    teammate
    team
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/teams/:team_id/asana_link' do
    it 'shows the team Asana link page' do
      get organization_team_team_asana_link_path(organization, team)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Team Asana Link')
      expect(response.body).to include(team.name)
    end

    it 'shows set up form when no link exists' do
      get organization_team_team_asana_link_path(organization, team)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Set up team Asana link')
      expect(response.body).to include('Asana project URL')
    end

    it 'shows existing team Asana link' do
      create(:team_asana_link, team: team, url: 'https://app.asana.com/0/123456/789')
      get organization_team_team_asana_link_path(organization, team)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('https://app.asana.com/0/123456/789')
    end

    it 'shows Asana link detection' do
      create(:team_asana_link, team: team, url: 'https://app.asana.com/0/123456/789')
      get organization_team_team_asana_link_path(organization, team)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Asana Project Detected')
    end

    it 'shows connect button when Asana link but viewing user has no identity' do
      create(:team_asana_link, team: team, url: 'https://app.asana.com/0/123456/789')
      get organization_team_team_asana_link_path(organization, team)
      expect(response).to have_http_status(:success)
      expect(response.body).to match(/Connect Your Asana Account|Asana Project Detected/)
    end

    it 'shows sync prompt when viewing user has Asana identity' do
      create(:teammate_identity, :asana, teammate: teammate)
      create(:team_asana_link, team: team, url: 'https://app.asana.com/0/123456/789')
      allow_any_instance_of(Organizations::Teams::TeamAsanaLinksController).to receive(:check_asana_project_access).and_return(true)
      get organization_team_team_asana_link_path(organization, team)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Ready to Sync')
      expect(response.body).to include('Sync Project')
    end

    it 'redirects when team not found' do
      get organization_team_team_asana_link_path(organization, 999999)
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(organization_teams_path(organization))
    end
  end

  describe 'POST /organizations/:organization_id/teams/:team_id/asana_link' do
    it 'creates a new team Asana link' do
      expect {
        post organization_team_team_asana_link_path(organization, team), params: {
          team_asana_link: { url: 'https://app.asana.com/0/111/222' }
        }
      }.to change(TeamAsanaLink, :count).by(1)
      expect(response).to redirect_to(organization_team_team_asana_link_path(organization, team))
      expect(flash[:notice]).to include('created successfully')
      expect(team.reload.team_asana_link.url).to eq('https://app.asana.com/0/111/222')
    end

    it 'extracts Asana project ID from URL' do
      post organization_team_team_asana_link_path(organization, team), params: {
        team_asana_link: { url: 'https://app.asana.com/0/123456/789' }
      }
      expect(response).to redirect_to(organization_team_team_asana_link_path(organization, team))
      link = team.reload.team_asana_link
      expect(link.asana_project_id).to eq('123456')
    end
  end

  describe 'PATCH /organizations/:organization_id/teams/:team_id/asana_link' do
    it 'updates existing team Asana link' do
      create(:team_asana_link, team: team, url: 'https://app.asana.com/0/old/1')
      patch organization_team_team_asana_link_path(organization, team), params: {
        team_asana_link: { url: 'https://app.asana.com/0/new/2' }
      }
      expect(response).to redirect_to(organization_team_team_asana_link_path(organization, team))
      expect(flash[:notice]).to include('updated successfully')
      expect(team.reload.team_asana_link.url).to eq('https://app.asana.com/0/new/2')
    end

    it 'validates URL format' do
      create(:team_asana_link, team: team, url: 'https://app.asana.com/0/1/2')
      patch organization_team_team_asana_link_path(organization, team), params: {
        team_asana_link: { url: 'not-a-valid-url' }
      }
      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).to include('must be a valid URL')
    end
  end

  describe 'POST /organizations/:organization_id/teams/:team_id/asana_link/sync' do
    let(:team_asana_link) { create(:team_asana_link, team: team, url: 'https://app.asana.com/0/123456/789') }

    before do
      team_asana_link
      allow_any_instance_of(AsanaService).to receive(:authenticated?).and_return(true)
      allow_any_instance_of(AsanaService).to receive(:fetch_project_sections).and_return(
        success: true,
        sections: [
          { 'gid' => 'section_1', 'name' => 'To Do' },
          { 'gid' => 'section_2', 'name' => 'In Progress' }
        ]
      )
      allow_any_instance_of(AsanaService).to receive(:fetch_all_project_tasks).and_return(
        success: true,
        incomplete: [
          { 'gid' => 'task_1', 'name' => 'Task 1', 'section_gid' => 'section_1', 'completed' => false }
        ],
        completed: []
      )
      allow_any_instance_of(AsanaService).to receive(:format_for_cache).and_return(
        sections: [
          { 'gid' => 'section_1', 'name' => 'To Do', 'position' => 0 },
          { 'gid' => 'section_2', 'name' => 'In Progress', 'position' => 1 }
        ],
        tasks: [
          { 'gid' => 'task_1', 'name' => 'Task 1', 'section_gid' => 'section_1', 'completed' => false }
        ]
      )
    end

    it 'syncs project data when user has Asana identity' do
      create(:teammate_identity, :asana, teammate: teammate)
      expect {
        post sync_organization_team_team_asana_link_path(organization, team), params: { source: 'asana' }
      }.to change(ExternalProjectCache, :count).by(1)
      expect(response).to redirect_to(organization_team_team_asana_link_path(organization, team))
      expect(flash[:notice]).to include('synced successfully')
    end

    it 'displays synced project data on the page' do
      create(:teammate_identity, :asana, teammate: teammate)
      post sync_organization_team_team_asana_link_path(organization, team), params: { source: 'asana' }
      get organization_team_team_asana_link_path(organization, team)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Asana Project')
      expect(response.body).to include('To Do')
      expect(response.body).to include('Task 1')
    end
  end

  describe 'GET /organizations/:organization_id/teams/:team_id/asana_link/items/:id' do
    let(:team_asana_link) { create(:team_asana_link, team: team, url: 'https://app.asana.com/0/123456/789') }

    before do
      team_asana_link
      create(:teammate_identity, :asana, teammate: teammate)
      allow_any_instance_of(AsanaService).to receive(:authenticated?).and_return(true)
      allow_any_instance_of(AsanaService).to receive(:fetch_task_details).and_return(
        'gid' => 'task_123',
        'name' => 'Team Task',
        'completed' => false
      )
    end

    it 'shows item details' do
      get organization_team_team_asana_link_item_path(organization, team, 'task_123', source: 'asana')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Team Task')
    end
  end

  describe 'authorization' do
    let(:other_person) { create(:person) }
    let(:other_teammate) do
      create(:teammate, person: other_person, organization: organization,
             first_employed_at: 1.year.ago, last_terminated_at: nil)
    end

    it 'allows team member to view team Asana link' do
      create(:team_member, team: team, company_teammate: other_teammate)
      sign_in_as_teammate_for_request(other_person, organization)
      get organization_team_team_asana_link_path(organization, team)
      expect(response).to have_http_status(:success)
    end

    it 'allows user with can_manage_departments_and_teams to view' do
      get organization_team_team_asana_link_path(organization, team)
      expect(response).to have_http_status(:success)
    end
  end
end
