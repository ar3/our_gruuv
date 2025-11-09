require 'rails_helper'

RSpec.describe Organizations::HuddlePlaybooksController, type: :controller do
  let(:person) { create(:person) }
  let(:organization) { create(:organization, name: 'Test Company', type: 'Company') }
  let(:huddle_playbook) { create(:huddle_playbook, organization: organization) }

  before do
    create(:teammate, person: person, organization: organization)
    sign_in_as_teammate(person, organization)
  end

  describe 'GET #show' do
    it 'returns http success' do
      get :show, params: { organization_id: organization.id, id: huddle_playbook.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct variables' do
      get :show, params: { organization_id: organization.id, id: huddle_playbook.id }
      
      expect(assigns(:organization).id).to eq(organization.id)
      expect(assigns(:huddle_playbook).id).to eq(huddle_playbook.id)
      expect(assigns(:huddles)).to be_a(ActiveRecord::AssociationRelation)
    end

    it 'loads huddles for the playbook' do
      huddle = create(:huddle, huddle_playbook: huddle_playbook)
      
      get :show, params: { organization_id: organization.id, id: huddle_playbook.id }
      
      expect(assigns(:huddles)).to include(huddle)
    end

    it 'handles huddles with feedback correctly' do
      huddle = create(:huddle, huddle_playbook: huddle_playbook)
      teammate = person.teammates.find_by(organization: organization)
      feedback = create(:huddle_feedback, huddle: huddle, teammate: teammate, 
                       informed_rating: 4, connected_rating: 4, goals_rating: 4, valuable_rating: 4)
      
      get :show, params: { organization_id: organization.id, id: huddle_playbook.id }
      
      expect(assigns(:huddles)).to include(huddle)
      expect(response).to have_http_status(:success)
    end

    it 'handles huddles without feedback correctly' do
      huddle = create(:huddle, huddle_playbook: huddle_playbook)
      
      get :show, params: { organization_id: organization.id, id: huddle_playbook.id }
      
      expect(assigns(:huddles)).to include(huddle)
      expect(response).to have_http_status(:success)
    end

    it 'loads participant statistics using service' do
      huddle1 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 1.week.ago)
      huddle2 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 2.weeks.ago)
      
      participant = create(:person, first_name: 'John', last_name: 'Doe')
      teammate = create(:teammate, person: participant, organization: organization)
      create(:huddle_participant, huddle: huddle1, teammate: teammate)
      create(:huddle_participant, huddle: huddle2, teammate: teammate)
      create(:huddle_feedback, huddle: huddle1, teammate: teammate)
      
      get :show, params: { organization_id: organization.id, id: huddle_playbook.id }
      
      expect(assigns(:participant_stats)).to be_present
      expect(assigns(:participant_stats).length).to eq(1)
      expect(assigns(:participant_stats).first.huddle_count).to eq(2)
      expect(assigns(:participant_stats).first.feedback_count).to eq(1)
    end

    it 'prevents SQL grouping errors with complex participant data' do
      # Create multiple huddles with multiple participants and feedback
      huddle1 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 1.week.ago)
      huddle2 = create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: 2.days.ago)
      huddle3 = create(:huddle, huddle_playbook: create(:huddle_playbook, organization: organization), started_at: 1.day.ago)
      
      participant1 = create(:person, first_name: 'John', last_name: 'Doe')
      participant2 = create(:person, first_name: 'Jane', last_name: 'Smith')
      
      teammate1 = create(:teammate, person: participant1, organization: organization)
      teammate2 = create(:teammate, person: participant2, organization: organization)
      
      # Participant 1 attends all huddles and gives feedback
      create(:huddle_participant, huddle: huddle1, teammate: teammate1)
      create(:huddle_participant, huddle: huddle2, teammate: teammate1)
      create(:huddle_participant, huddle: huddle3, teammate: teammate1)
      create(:huddle_feedback, huddle: huddle1, teammate: teammate1)
      create(:huddle_feedback, huddle: huddle2, teammate: teammate1)
      
      # Participant 2 attends only first two huddles and gives one feedback
      create(:huddle_participant, huddle: huddle1, teammate: teammate2)
      create(:huddle_participant, huddle: huddle2, teammate: teammate2)
      create(:huddle_feedback, huddle: huddle1, teammate: teammate2)
      
      expect {
        get :show, params: { organization_id: organization.id, id: huddle_playbook.id }
      }.not_to raise_error
      
      expect(response).to have_http_status(:success)
      expect(assigns(:participant_stats)).to be_present
      expect(assigns(:participant_stats).length).to eq(2)
    end

    it 'does not show duplicate participants' do
      huddle1 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 1.week.ago)
      huddle2 = create(:huddle, huddle_playbook: huddle_playbook, started_at: 2.weeks.ago)
      
      participant = create(:person, first_name: 'John', last_name: 'Doe')
      teammate = create(:teammate, person: participant, organization: organization)
      
      # Same participant in multiple huddles with multiple feedbacks
      create(:huddle_participant, huddle: huddle1, teammate: teammate)
      create(:huddle_participant, huddle: huddle2, teammate: teammate)
      create(:huddle_feedback, huddle: huddle1, teammate: teammate)
      create(:huddle_feedback, huddle: huddle2, teammate: teammate)
      
      get :show, params: { organization_id: organization.id, id: huddle_playbook.id }
      
      expect(assigns(:participant_stats).length).to eq(1)
      expect(assigns(:participant_stats).first.person_id).to eq(participant.id)
      expect(assigns(:participant_stats).first.huddle_count).to eq(2)
      expect(assigns(:participant_stats).first.feedback_count).to eq(2)
    end
  end
end 