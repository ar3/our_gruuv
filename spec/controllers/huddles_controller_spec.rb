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
