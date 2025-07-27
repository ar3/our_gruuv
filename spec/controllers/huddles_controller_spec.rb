require 'rails_helper'

RSpec.describe HuddlesController, type: :controller do
  let(:organization) { create(:organization, name: 'Test Org') }
  let!(:slack_config) { create(:slack_configuration, organization: organization) }
  let(:huddle) { create(:huddle, organization: organization, started_at: Time.current) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let!(:participant) { create(:huddle_participant, huddle: huddle, person: person, role: 'active') }

  before do
    session[:current_person_id] = person.id
  end

  describe 'GET #show' do
    it 'assigns the requested huddle' do
      get :show, params: { id: huddle.id }
      expect(assigns(:huddle)).to eq(huddle)
    end

    it 'redirects to join page when user is not logged in' do
      session[:current_person_id] = nil
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
        informed_rating: '4',
        connected_rating: '5',
        goals_rating: '3',
        valuable_rating: '4',
        personal_conflict_style: 'Collaborative',
        team_conflict_style: 'Compromising',
        appreciation: 'Great meeting!',
        change_suggestion: 'More time for discussion',
        private_department_head: 'Private feedback for DH',
        private_facilitator: 'Private feedback for facilitator',
        anonymous: '0'
      }
    end

    context 'with valid parameters' do
      it 'creates a new feedback record' do
        expect {
          post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        }.to change(HuddleFeedback, :count).by(1)
      end

      it 'saves all the feedback data correctly' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        feedback = HuddleFeedback.last
        expect(feedback.person).to eq(person)
        expect(feedback.huddle).to eq(huddle)
        expect(feedback.informed_rating).to eq(4)
        expect(feedback.connected_rating).to eq(5)
        expect(feedback.goals_rating).to eq(3)
        expect(feedback.valuable_rating).to eq(4)
        expect(feedback.personal_conflict_style).to eq('Collaborative')
        expect(feedback.team_conflict_style).to eq('Compromising')
        expect(feedback.appreciation).to eq('Great meeting!')
        expect(feedback.change_suggestion).to eq('More time for discussion')
        expect(feedback.private_department_head).to eq('Private feedback for DH')
        expect(feedback.private_facilitator).to eq('Private feedback for facilitator')
        expect(feedback.anonymous).to be false
      end
    end

    context 'with conflict styles only' do
      let(:conflict_only_params) do
        {
          informed_rating: '4',
          connected_rating: '5',
          goals_rating: '3',
          valuable_rating: '4',
          personal_conflict_style: 'Competing',
          team_conflict_style: 'Avoiding'
        }
      end

      it 'saves conflict styles correctly' do
        post :submit_feedback, params: { id: huddle.id }.merge(conflict_only_params)
        
        feedback = HuddleFeedback.last
        expect(feedback.personal_conflict_style).to eq('Competing')
        expect(feedback.team_conflict_style).to eq('Avoiding')
      end
    end

    context 'with anonymous feedback' do
      let(:anonymous_params) do
        valid_feedback_params.merge(anonymous: '1')
      end

      it 'saves anonymous flag correctly' do
        post :submit_feedback, params: { id: huddle.id }.merge(anonymous_params)
        
        feedback = HuddleFeedback.last
        expect(feedback.anonymous).to be true
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          informed_rating: '6', # Invalid rating
          connected_rating: '5',
          goals_rating: '3',
          valuable_rating: '4'
        }
      end

      it 'does not create a feedback record' do
        expect {
          post :submit_feedback, params: { id: huddle.id }.merge(invalid_params)
        }.not_to change(HuddleFeedback, :count)
      end

      it 'renders feedback form with errors' do
        post :submit_feedback, params: { id: huddle.id }.merge(invalid_params)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:feedback)
      end
    end

    context 'when user is not logged in' do
      before do
        session[:current_person_id] = nil
      end

      it 'redirects to join page' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        expect(response).to redirect_to(join_huddle_path(huddle))
      end
    end

    context 'when user is not a participant' do
      before do
        participant.destroy
      end

      it 'redirects to join page' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        expect(response).to redirect_to(join_huddle_path(huddle))
      end
    end
  end





  describe 'POST #post_start_announcement_to_slack' do
    let(:slack_config) { create(:slack_configuration, organization: organization) }

    before do
      slack_config
      allow(Huddles::PostAnnouncementJob).to receive(:perform_now)
    end

    it 'assigns the requested huddle' do
      post :post_start_announcement_to_slack, params: { id: huddle.id }
      expect(assigns(:huddle)).to eq(huddle)
    end

    it 'redirects to huddle page with success message when Slack is configured' do
      post :post_start_announcement_to_slack, params: { id: huddle.id }
      
      expect(response).to redirect_to(huddle_path(huddle))
      expect(flash[:notice]).to eq('Huddle start announcement posted to Slack successfully!')
    end

    it 'redirects to huddle page with error when Slack is not configured' do
      slack_config.destroy
      
      post :post_start_announcement_to_slack, params: { id: huddle.id }
      
      expect(response).to redirect_to(huddle_path(huddle))
      expect(flash[:alert]).to eq('Slack is not configured for this organization.')
    end

    it 'redirects to huddle page with error when Slack service fails' do
      allow(Huddles::PostAnnouncementJob).to receive(:perform_now).and_raise(StandardError.new('Slack error'))
      
      post :post_start_announcement_to_slack, params: { id: huddle.id }
      
      expect(response).to redirect_to(huddle_path(huddle))
      expect(flash[:alert]).to eq('Failed to post to Slack: Slack error')
    end
  end
end 