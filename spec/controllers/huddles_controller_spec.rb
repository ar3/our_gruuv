require 'rails_helper'

RSpec.describe HuddlesController, type: :controller do
  let(:organization) { create(:organization, name: 'Test Org') }
  let!(:slack_config) { create(:slack_configuration, organization: organization) }
  let(:team) { create(:team, company: organization) }
  let(:huddle) { create(:huddle, team: team, started_at: Time.current) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let!(:teammate) { create(:teammate, person: person, organization: organization) }
  let!(:participant) { create(:huddle_participant, huddle: huddle, teammate: teammate, role: 'active') }

  before do
    session[:current_company_teammate_id] = teammate.id
  end

  describe 'GET #new' do
    context 'when user is not logged in' do
      before do
        session[:current_company_teammate_id] = nil
      end

      it 'redirects to root path' do
        get :new
        expect(response).to redirect_to(root_path)
      end

      it 'sets an error flash message' do
        get :new
        expect(flash[:error]).to eq('You must be logged in to access this page')
      end
    end

    context 'when user is logged in' do
      it 'returns a success response' do
        get :new
        expect(response).to be_successful
      end

      it 'assigns @current_person' do
        get :new
        expect(assigns(:current_person)).to eq(person)
      end

      it 'assigns @teams_by_company with teams from user companies' do
        get :new
        expect(assigns(:teams_by_company)).to be_a(Hash)
        company_ids = assigns(:teams_by_company).keys.map(&:id)
        expect(company_ids).to include(organization.id)
        
        company_teams = assigns(:teams_by_company).values.flatten
        expect(company_teams.map(&:id)).to include(team.id)
      end

      context 'with multiple companies' do
        let(:second_organization) { create(:organization, name: 'Second Org') }
        let!(:second_team) { create(:team, name: 'Second Team', company: second_organization) }
        let!(:second_teammate) { create(:teammate, person: person, organization: second_organization) }

        it 'includes teams from all user companies' do
          get :new
          company_ids = assigns(:teams_by_company).keys.map(&:id)
          expect(company_ids).to include(organization.id, second_organization.id)
        end

        it 'sorts companies by name' do
          get :new
          company_names = assigns(:teams_by_company).keys.map(&:name)
          expect(company_names).to eq(company_names.sort)
        end
      end

      context 'with archived teams' do
        let!(:archived_team) { create(:team, name: 'Archived Team', company: organization, deleted_at: Time.current) }

        it 'does not include archived teams' do
          get :new
          # Find the company in the result by ID since STI returns Company class
          company_entry = assigns(:teams_by_company).find { |c, _| c.id == organization.id }
          expect(company_entry).to be_present
          teams = company_entry.last
          expect(teams.map(&:id)).not_to include(archived_team.id)
        end
      end

      context 'when user has no teams' do
        let(:org_without_teams) { create(:organization, name: 'Empty Org') }
        let(:person_without_teams) { create(:person, first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com') }
        let!(:teammate_without_teams) { create(:teammate, person: person_without_teams, organization: org_without_teams) }

        before do
          session[:current_company_teammate_id] = teammate_without_teams.id
        end

        it 'assigns empty teams_by_company' do
          get :new
          expect(assigns(:teams_by_company)).to be_empty
        end
      end
    end
  end

  describe 'GET #show' do
    it 'assigns the requested huddle' do
      get :show, params: { id: huddle.id }
      expect(assigns(:huddle)).to eq(huddle)
    end

    it 'redirects to join page when user is not logged in' do
      session[:current_company_teammate_id] = nil
      get :show, params: { id: huddle.id }
      expect(response).to redirect_to(join_huddle_path(huddle))
    end

    it 'renders successfully when a participant has a nil teammate (orphaned record)' do
      other_person = create(:person, first_name: 'Jane', last_name: 'Doe', email: 'jane@example.com')
      other_teammate = create(:teammate, person: other_person, organization: organization)
      orphan_participant = create(:huddle_participant, huddle: huddle, teammate: other_teammate, role: 'active')
      orphan_participant.update_columns(teammate_id: nil)
      get :show, params: { id: huddle.id }
      expect(response).to be_successful
    end
  end

  describe 'GET #feedback' do
    it 'assigns the requested huddle' do
      get :feedback, params: { id: huddle.id }
      expect(assigns(:huddle)).to eq(huddle)
    end

    it 'assigns the current person' do
      get :feedback, params: { id: huddle.id }
      expect(assigns(:current_person)).to eq(person)
    end

    it 'assigns existing participant' do
      get :feedback, params: { id: huddle.id }
      expect(assigns(:existing_participant)).to eq(participant)
    end
  end

  describe 'POST #submit_feedback' do
    let(:valid_feedback_params) do
      {
        id: huddle.id,
        informed_rating: 4,
        connected_rating: 4,
        goals_rating: 4,
        valuable_rating: 4
      }
    end

    context 'when user is a participant' do
      it 'creates feedback successfully' do
        expect {
          post :submit_feedback, params: valid_feedback_params
        }.to change(HuddleFeedback, :count).by(1)
      end

      it 'redirects to huddle path' do
        post :submit_feedback, params: valid_feedback_params
        expect(response).to redirect_to(huddle_path(huddle))
      end
    end
  end

  describe 'POST #post_start_announcement_to_slack' do
    before do
      team.third_party_object_associations.create!(
        third_party_object: create(:third_party_object, organization: organization, third_party_source: 'slack', third_party_object_type: 'channel', third_party_id: 'C123'),
        association_type: 'huddle_channel'
      )
      allow(Huddles::PostAnnouncementJob).to receive(:perform_and_get_result)
        .and_return(success: true, message_id: '123', channel: '#general')
    end

    it 'posts announcement to slack' do
      expect(Huddles::PostAnnouncementJob).to receive(:perform_and_get_result).with(huddle.id)
      post :post_start_announcement_to_slack, params: { id: huddle.id }
    end

    it 'redirects to huddle path' do
      post :post_start_announcement_to_slack, params: { id: huddle.id }
      expect(response).to redirect_to(huddle_path(huddle))
    end
  end

  describe 'POST #start_huddle_from_team' do
    let(:start_team) { create(:team, company: organization) }

    before do
      allow(Huddles::PostAnnouncementJob).to receive(:perform_and_get_result)
      allow(Huddles::PostSummaryJob).to receive(:perform_and_get_result)
      allow(Companies::WeeklyHuddlesReviewNotificationJob).to receive(:perform_later)
    end

    it 'creates a huddle for the specified team' do
      expect {
        post :start_huddle_from_team, params: { team_id: start_team.id }
      }.to change(Huddle, :count).by(1)

      created_huddle = Huddle.last
      expect(created_huddle.team).to eq(start_team)
    end

    context 'when team is not found' do
      it 'redirects with an error' do
        post :start_huddle_from_team, params: { team_id: 99999 }
        expect(response).to redirect_to(huddles_path)
        expect(flash[:alert]).to be_present
      end
    end
  end
end
