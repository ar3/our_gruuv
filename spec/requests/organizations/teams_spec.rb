# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Organizations::Teams (edit page)', type: :request do
  let(:organization) { create(:organization, name: 'Test Company') }
  let(:person) { create(:person) }
  let(:team) { create(:team, company: organization, name: 'Engineering') }

  # Teammate who can update teams (policy: can_manage_departments_and_teams or team member)
  let(:teammate) do
    create(:teammate, person: person, organization: organization,
           first_employed_at: 1.year.ago, last_terminated_at: nil,
           can_manage_departments_and_teams: true)
  end

  before do
    teammate
    sign_in_as_teammate_for_request(person, organization)
  end

  describe 'GET /organizations/:organization_id/teams/:id/edit' do
    let(:edit_path) { edit_organization_team_path(organization, team) }

    it 'returns http success' do
      get edit_path
      expect(response).to have_http_status(:success)
    end

    it 'renders the edit team page' do
      get edit_path
      expect(response.body).to include('Edit Team')
      expect(response.body).to include('Team Name')
      expect(response.body).to include(team.name)
      expect(response.body).to include('Update Team')
      expect(response.body).to include(organization_team_path(organization, team))
      expect(response.body).to include('Profile picture')
    end

    it 'includes department select when organization has departments' do
      dept = create(:department, company: organization, name: 'Engineering')
      get edit_path
      expect(response.body).to include('Department')
      expect(response.body).to include('Company-wide (no department)')
      expect(response.body).to include(dept.display_name)
    end

    it 'includes form that submits to team update path' do
      get edit_path
      expect(response.body).to include(organization_team_path(organization, team))
    end

    context 'when company has Slack configured and has Slack channels' do
      let!(:slack_config) { create(:slack_configuration, organization: organization) }
      let!(:slack_channel1) do
        create(:third_party_object, :slack_channel, organization: organization,
               third_party_id: 'C111', display_name: '#general')
      end
      let!(:slack_channel2) do
        create(:third_party_object, :slack_channel, organization: organization,
               third_party_id: 'C222', display_name: '#engineering')
      end

      before do
        allow(SlackService).to receive(:new).with(kind_of(Organization)).and_return(instance_double(SlackService))
      end

      it 'returns http success' do
        get edit_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the Slack channel for huddles select' do
        get edit_path
        expect(response.body).to include('Slack channel for huddles')
        expect(response.body).to include('#general')
        expect(response.body).to include('#engineering')
        expect(response.body).to include('notifications will be posted to this channel')
        expect(response.body).to include('Channels already used by other teams are disabled')
      end

      it 'includes channel option values for the select' do
        get edit_path
        expect(response.body).to include('C111')
        expect(response.body).to include('C222')
      end

      context 'when another team already uses a channel' do
        let!(:other_team) { create(:team, company: organization, name: 'Product') }

        before do
          other_team.third_party_object_associations.create!(
            third_party_object: slack_channel1,
            association_type: 'huddle_channel'
          )
        end

        it 'still renders the edit page with both channels listed' do
          get edit_path
          expect(response).to have_http_status(:success)
          expect(response.body).to include('Slack channel for huddles')
          expect(response.body).to include('#general')
          expect(response.body).to include('#engineering')
        end
      end
    end

    context 'when company does not have Slack configured' do
      it 'returns http success' do
        get edit_path
        expect(response).to have_http_status(:success)
      end

      it 'renders the edit form without the Slack channel select' do
        get edit_path
        expect(response.body).to include('Edit Team')
        expect(response.body).to include('Team Name')
        expect(response.body).not_to include('Slack channel for huddles')
      end
    end

    context 'when company has Slack config but no channels synced yet' do
      let!(:slack_config) { create(:slack_configuration, organization: organization) }

      before do
        allow(SlackService).to receive(:new).with(kind_of(Organization)).and_return(instance_double(SlackService))
      end

      it 'returns http success' do
        get edit_path
        expect(response).to have_http_status(:success)
      end

      it 'does not show the Slack channel select when channels list is empty' do
        get edit_path
        # @slack_channels is loaded but empty, so the form partial condition
        # team.persisted? && @slack_channels.present? is false - no select shown
        expect(response.body).to include('Edit Team')
        expect(response.body).not_to include('Slack channel for huddles')
      end
    end

    context 'when not signed in' do
      before { sign_out_teammate_for_request }

      it 'redirects to root path' do
        get edit_path
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(root_path)
      end
    end
  end

  describe 'POST /organizations/:organization_id/teams' do
    it 'creates a team with department_id when provided' do
      dept = create(:department, company: organization, name: 'Engineering')
      expect {
        post organization_teams_path(organization), params: { team: { name: 'New Team', department_id: dept.id } }
      }.to change(Team, :count).by(1)
      expect(response).to have_http_status(:redirect)
      created = Team.find_by(name: 'New Team', company: organization)
      expect(created.department_id).to eq(dept.id)
    end
  end

  describe 'PATCH /organizations/:organization_id/teams/:id' do
    let(:update_path) { organization_team_path(organization, team) }

    it 'updates the team name and redirects to team show' do
      patch update_path, params: { team: { name: 'Updated Team Name' } }
      expect(response).to have_http_status(:redirect)
      expect(response).to redirect_to(organization_team_path(organization, team.reload))
      expect(team.name).to eq('Updated Team Name')
    end

    context 'when company has Slack configured' do
      let!(:slack_config) { create(:slack_configuration, organization: organization) }
      let!(:slack_channel) do
        create(:third_party_object, :slack_channel, organization: organization,
               third_party_id: 'C999', display_name: '#huddles')
      end

      it 'updates huddle_channel_id and redirects' do
        patch update_path, params: {
          team: { name: team.name, huddle_channel_id: slack_channel.third_party_id }
        }
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(organization_team_path(organization, team.reload))
        expect(team.huddle_channel_id).to eq(slack_channel.third_party_id)
      end

      it 'clears huddle_channel_id when passed blank' do
        team.third_party_object_associations.create!(
          third_party_object: slack_channel,
          association_type: 'huddle_channel'
        )
        expect(team.reload.huddle_channel_id).to eq(slack_channel.third_party_id)

        patch update_path, params: { team: { name: team.name, huddle_channel_id: '' } }
        expect(response).to have_http_status(:redirect)
        expect(team.reload.huddle_channel_id).to be_nil
      end
    end

    it 'updates department_id when provided' do
      dept = create(:department, company: organization, name: 'Product')
      patch update_path, params: { team: { name: team.name, department_id: dept.id } }
      expect(response).to have_http_status(:redirect)
      expect(team.reload.department_id).to eq(dept.id)
    end

    it 'clears department when department_id is blank' do
      dept = create(:department, company: organization, name: 'Product')
      team.update!(department_id: dept.id)
      patch update_path, params: { team: { name: team.name, department_id: '' } }
      expect(response).to have_http_status(:redirect)
      expect(team.reload.department_id).to be_nil
    end
  end

  describe 'GET /organizations/:organization_id/teams' do
    it 'groups teams by department with No Department section' do
      team_no_dept = create(:team, company: organization, name: 'Standalone', department_id: nil)
      dept = create(:department, company: organization, name: 'Engineering')
      team_in_dept = create(:team, company: organization, name: 'Backend', department: dept)
      get organization_teams_path(organization)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('No Department')
      expect(response.body).to include(dept.display_name)
      expect(response.body).to include(team_no_dept.name)
      expect(response.body).to include(team_in_dept.name)
      expect(response.body).to include(organization_department_path(organization, dept))
    end
  end

  describe 'GET /organizations/:organization_id/teams/:id' do
    it 'displays department when set' do
      dept = create(:department, company: organization, name: 'Engineering')
      team.update!(department: dept)
      get organization_team_path(organization, team)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Department')
      expect(response.body).to include(dept.display_name)
      expect(response.body).to include(organization_department_path(organization, dept))
    end

    it 'displays No department when team has no department' do
      get organization_team_path(organization, team)
      expect(response).to have_http_status(:success)
      expect(response.body).to include('No department')
    end

    it 'collapses member names/emails by default and shows team goals under members' do
      member_person = create(:person, first_name: 'Casey', last_name: 'Member', email: 'casey@example.com')
      member = create(:teammate, person: member_person, organization: organization,
                      first_employed_at: 1.year.ago, last_terminated_at: nil)
      create(:team_member, team: team, company_teammate: member)
      team_goal = create(
        :goal,
        creator: teammate,
        owner: team,
        title: 'Ship the platform rock',
        started_at: 1.week.ago,
        privacy_level: 'everyone_in_company'
      )

      get organization_team_path(organization, team)

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Team Members')
      expect(response.body).to include('Names and emails')
      expect(response.body).to include('id="team-members-directory"')
      expect(response.body).to include('aria-expanded="false"')
      expect(response.body).to match(/class="[^"]*\bcollapse\b/)
      expect(response.body).to include('casey@example.com')
      expect(response.body).to include('Team Goals')
      expect(response.body).to include('Ship the platform rock')
      expect(response.body).to include(organization_goal_path(organization, team_goal))
      expect(response.body).to include(organization_goals_path(organization, owner_id: "Team_#{team.id}"))
      expect(response.body).to include(new_organization_goal_path(organization, owner_id: "Team_#{team.id}"))
      # Team Goals card should appear after Team Members in the markup
      expect(response.body.index('Team Members')).to be < response.body.index('Team Goals')
    end
  end

  describe 'GET /organizations/:organization_id/teams/:id/manage_members' do
    let(:manage_members_path) { manage_members_organization_team_path(organization, team) }

    let(:member_person) { create(:person, first_name: 'Alex', last_name: 'Member') }
    let!(:member_teammate) do
      create(:teammate, person: member_person, organization: organization,
             first_employed_at: 1.year.ago, last_terminated_at: nil)
    end
    let!(:member_tenure) do
      create(:employment_tenure, company_teammate: member_teammate, company: organization)
    end
    let!(:engineering_department) { create(:department, company: organization, name: 'Engineering') }

    let(:terminated_person) { create(:person, first_name: 'Gone', last_name: 'Former') }
    let!(:terminated_teammate) do
      create(:teammate, person: terminated_person, organization: organization,
             first_employed_at: 6.months.ago, last_terminated_at: 1.month.ago)
    end

    it 'renders the manage members page with selection toolbar UX' do
      get manage_members_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include('Manage Members')
      expect(response.body).to include('Select Team Members')
      expect(response.body).to include('Search teammates...')
      expect(response.body).to include('data-controller="selection-toolbar options-filter"')
      expect(response.body).to include('None selected')
      expect(response.body).to include('teammate_ids[]')
      assert_select 'input[type="submit"][value="Save Changes"]', count: 2
    end

    it 'shows active teammates with department metadata and excludes terminated' do
      member_tenure.position.title.update!(department: engineering_department)

      get manage_members_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(member_person.preferred_first_then_last_display_name)
      expect(response.body).to include('Department: Engineering')
      expect(response.body).not_to include(terminated_person.preferred_first_then_last_display_name)
    end
  end

  describe 'PATCH /organizations/:organization_id/teams/:id/update_members' do
    let!(:teammate1) do
      create(:teammate, organization: organization, first_employed_at: 1.year.ago, last_terminated_at: nil)
    end
    let!(:teammate2) do
      create(:teammate, organization: organization, first_employed_at: 1.year.ago, last_terminated_at: nil)
    end

    it 'updates team members and redirects to team show' do
      expect {
        patch update_members_organization_team_path(organization, team), params: {
          teammate_ids: [teammate1.id, teammate2.id]
        }
      }.to change { team.team_members.count }.by(2)

      expect(response).to redirect_to(organization_team_path(organization, team))
    end
  end

  describe 'PATCH /organizations/:organization_id/teams/:id' do
    it 'attaches a profile picture' do
      image = fixture_file_upload('logo.png', 'image/png')
      expect {
        patch organization_team_path(organization, team), params: {
          team: { name: team.name, profile_image: image }
        }
      }.to change { team.reload.profile_image.attached? }.from(false).to(true)
      expect(response).to redirect_to(organization_team_path(organization, team))
    end

    it 'removes a profile picture when remove_profile_image is set' do
      team.profile_image.attach(
        io: StringIO.new(File.binread(Rails.root.join('spec/fixtures/files/logo.png'))),
        filename: 'logo.png',
        content_type: 'image/png'
      )

      patch organization_team_path(organization, team), params: {
        team: { name: team.name, remove_profile_image: '1' }
      }

      expect(response).to redirect_to(organization_team_path(organization, team))
      expect(team.reload.profile_image.attached?).to eq(false)
    end
  end

  describe 'GET /organizations/:id/my_teams' do
    it 'redirects to teams index with member_of=me' do
      get my_teams_organization_path(organization)
      expect(response).to have_http_status(:redirect)
      expect(response.redirect_url).to include("/organizations/#{organization.to_param}/teams")
      expect(response.redirect_url).to include('member_of=me')
    end
  end

  describe 'GET /organizations/:organization_id/teams with member_of=me' do
    it 'shows only teams the current teammate is a member of' do
      other_team = create(:team, company: organization, name: 'Other Team')
      create(:team_member, team: team, company_teammate: teammate)
      get organization_teams_path(organization, member_of: 'me')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('My Teams')
      expect(response.body).to include(team.name)
      expect(response.body).not_to include(other_team.name)
    end

    it 'shows toggle for "Show all Teams" and "Show Just My Teams" when filtered' do
      get organization_teams_path(organization, member_of: 'me')
      expect(response).to have_http_status(:success)
      expect(response.body).to include('Show all Teams')
      expect(response.body).to include('Show Just My Teams')
    end
  end
end
