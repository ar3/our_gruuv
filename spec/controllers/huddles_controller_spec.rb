require 'rails_helper'

RSpec.describe HuddlesController, type: :controller do
  let(:organization) { create(:organization, name: 'Test Org') }
  let(:huddle) { create(:huddle, organization: organization, started_at: 1.day.ago) }
  let(:person) { create(:person, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let!(:participant) { create(:huddle_participant, huddle: huddle, person: person, role: 'active') }

  before do
    session[:current_person_id] = person.id
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

      it 'redirects to huddle with success message' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        expect(response).to redirect_to(huddle_path(huddle))
        expect(flash[:notice]).to eq('Thank you for your feedback!')
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
        expect(flash[:alert]).to eq('Please join the huddle before accessing this page.')
      end
    end

    context 'when user is not a participant' do
      let(:non_participant) { create(:person, first_name: 'Jane', last_name: 'Smith', email: 'jane@example.com') }

      before do
        session[:current_person_id] = non_participant.id
      end

      it 'redirects to join page' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        expect(response).to redirect_to(join_huddle_path(huddle))
        expect(flash[:alert]).to eq('Please join the huddle before accessing this page.')
      end
    end

    context 'with duplicate feedback submission' do
      let!(:existing_feedback) { create(:huddle_feedback, huddle: huddle, person: person) }

      it 'renders feedback form with errors' do
        post :submit_feedback, params: { id: huddle.id }.merge(valid_feedback_params)
        
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response).to render_template(:feedback)
      end
    end
  end

  describe 'GET #feedback' do
    context 'when user is logged in and is a participant' do
      it 'renders the feedback form' do
        get :feedback, params: { id: huddle.id }
        
        expect(response).to have_http_status(:success)
        expect(response).to render_template(:feedback)
        expect(assigns(:current_person)).to eq(person)
        expect(assigns(:existing_participant)).to eq(participant)
      end
    end

    context 'when user is not logged in' do
      before do
        session[:current_person_id] = nil
      end

      it 'redirects to join page' do
        get :feedback, params: { id: huddle.id }
        
        expect(response).to redirect_to(join_huddle_path(huddle))
        expect(flash[:alert]).to eq('Please join the huddle before accessing this page.')
      end
    end

    context 'when user is not a participant' do
      let(:non_participant) { create(:person, first_name: 'Jane', last_name: 'Smith', email: 'jane@example.com') }

      before do
        session[:current_person_id] = non_participant.id
      end

      it 'redirects to join page' do
        get :feedback, params: { id: huddle.id }
        
        expect(response).to redirect_to(join_huddle_path(huddle))
        expect(flash[:alert]).to eq('Please join the huddle before accessing this page.')
      end
    end
  end
end 